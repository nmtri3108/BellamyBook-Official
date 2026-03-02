#!/usr/bin/env bash
set -e

MONGO_HOST="${MONGO_HOST:-mongodb}"
MONGO_PORT="${MONGO_PORT:-27017}"
MAX_WAIT="${MAX_WAIT:-300}"
# When replica is already initialized (redeploy), wait at most this long for PRIMARY then allow deploy to proceed
REDEPLOY_WAIT="${REDEPLOY_WAIT:-90}"

if [ -z "$MONGO_ROOT_USERNAME" ] || [ -z "$MONGO_ROOT_PASSWORD" ]; then
  echo "ERROR: MONGO_ROOT_USERNAME and MONGO_ROOT_PASSWORD must be set."
  exit 1
fi

echo "Waiting 15s for MongoDB to be ready..."
sleep 15

# Track if we ran rs.initiate() in this run (fresh deploy). If not, replica was already there (redeploy).
INITIALIZED_THIS_RUN=false

# Retry "already initialized?" check (redeploy: mongodb may be RECOVERING for a few seconds)
echo "Checking if replica set rs0 is already initialized..."
for attempt in 1 2 3 4 5 6 7 8; do
  if mongosh "mongodb://${MONGO_HOST}:${MONGO_PORT}/admin" \
    -u "$MONGO_ROOT_USERNAME" -p "$MONGO_ROOT_PASSWORD" \
    --quiet --eval 'db.adminCommand("replSetGetStatus").ok' 2>&1 | grep -q 1; then
    echo "Replica set already initialized (redeploy or existing data)."
    break
  fi
  if [ "$attempt" -lt 8 ]; then
    echo "Attempt $attempt: replica set not ready, retrying in 5s..."
    sleep 5
  else
    # Use stable host (e.g. mongodb:27017) so replica set survives container restarts.
    # Plain rs.initiate() uses container ID as host → after redeploy new ID breaks the set (Host not found).
    echo "Initializing replica set rs0 with host ${MONGO_HOST}:${MONGO_PORT} (fresh deploy)..."
    init_out=$(mongosh "mongodb://${MONGO_HOST}:${MONGO_PORT}/admin" \
      -u "$MONGO_ROOT_USERNAME" -p "$MONGO_ROOT_PASSWORD" \
      --eval "rs.initiate({ _id: 'rs0', members: [ { _id: 0, host: '${MONGO_HOST}:${MONGO_PORT}' } ] })" 2>&1) || true
    # If set was already there (redeploy), we must not fail the pipeline when PRIMARY wait times out
    if echo "$init_out" | grep -qi "already initialized"; then
      echo "Replica set was already initialized (redeploy). Will wait for PRIMARY; if timeout, deploy will still proceed."
      INITIALIZED_THIS_RUN=false
    else
      INITIALIZED_THIS_RUN=true
    fi
  fi
done

# Redeploy: replica already initialized — use shorter wait; allow deploy to proceed on timeout
# First deploy: must see PRIMARY within MAX_WAIT or fail
if [ "$INITIALIZED_THIS_RUN" = false ]; then
  WAIT_LIMIT=$REDEPLOY_WAIT
  echo "Redeploy: replica already initialized. Waiting for PRIMARY (max ${WAIT_LIMIT}s); then deploy may proceed."
else
  WAIT_LIMIT=$MAX_WAIT
  echo "Waiting for primary to be elected (max ${WAIT_LIMIT}s)..."
fi

state=""
for i in $(seq 1 "$WAIT_LIMIT"); do
  raw=$(mongosh "mongodb://${MONGO_HOST}:${MONGO_PORT}/admin" \
    -u "$MONGO_ROOT_USERNAME" -p "$MONGO_ROOT_PASSWORD" \
    --quiet --eval 'try { var s=db.adminCommand("replSetGetStatus"); if(s.ok&&s.members&&s.members[0]) print(s.members[0].stateStr); } catch(e) {}' 2>/dev/null || echo "")
  state=$(echo "$raw" | tr -d '\n\r \t')
  if [[ "$state" == *"PRIMARY"* ]]; then
    echo "Primary elected."
    exit 0
  fi
  if [ $((i % 15)) -eq 0 ]; then
    echo "Still waiting for PRIMARY (${i}s), state=[${state}]"
  fi
  sleep 1
done

# Redeploy: already initialized — allow deploy to proceed; node will become PRIMARY soon
if [ "$INITIALIZED_THIS_RUN" = false ]; then
  echo "WARNING: Replica already initialized but PRIMARY not seen within ${REDEPLOY_WAIT}s (state=[${state}])."
  echo "Allowing deploy to proceed (replica only needs init on first deploy). Node may still be RECOVERING."
  exit 0
fi

# First deploy: must see PRIMARY
echo "ERROR: Primary not elected within ${MAX_WAIT}s. state=[${state}]"
echo "If MongoDB logs show 'Host not found' for a container ID (e.g. 3c6e7599bb95): replica set was inited with old container hostname. Fix: remove mongo_data volume and redeploy (fresh init uses mongodb:27017)."
echo "Otherwise: verify MONGO_ROOT_* and mongo-keyfile."
exit 1
