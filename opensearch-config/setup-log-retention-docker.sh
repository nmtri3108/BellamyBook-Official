#!/bin/bash
# Docker-friendly: wait for Elasticsearch/OpenSearch and apply N-day log retention (align with dockerLocalENV).
# Used by elasticsearch-init service.
# Set LOG_RETENTION_DAYS (default 5) to control how long logs are kept; older indices are deleted automatically.

set -e
OPENSEARCH_URL="${OPENSEARCH_URL:-http://elasticsearch:9200}"
LOG_RETENTION_DAYS="${LOG_RETENTION_DAYS:-5}"
MAX_RETRIES=30
RETRY_DELAY=5
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Elasticsearch/OpenSearch Log Retention${NC}"
echo -e "${BLUE}Retention: ${LOG_RETENTION_DAYS} days (set LOG_RETENTION_DAYS to change)${NC}"
echo -e "${BLUE}========================================${NC}"

RETRY_COUNT=0
while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s -f "$OPENSEARCH_URL" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Elasticsearch/OpenSearch is ready${NC}"
    break
  fi
  RETRY_COUNT=$((RETRY_COUNT + 1))
  if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
    echo -e "${RED}✗ Elasticsearch/OpenSearch failed to start after ${MAX_RETRIES} attempts${NC}"
    exit 1
  fi
  echo "  Attempt $RETRY_COUNT/$MAX_RETRIES..."
  sleep $RETRY_DELAY
done

check_response() {
  HTTP_CODE=$(echo "$1" | tail -n1)
  BODY=$(echo "$1" | sed '$d')
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓ Success (HTTP $HTTP_CODE)${NC}"
    return 0
  else
    echo -e "${RED}✗ Failed (HTTP $HTTP_CODE)${NC}"
    if [ -n "$BODY" ]; then
      echo "$BODY" | head -5
    fi
    return 1
  fi
}

detect_cluster_type() {
  RESPONSE=$(curl -s -w '\n%{http_code}' "$OPENSEARCH_URL/")
  HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    BODY=$(echo "$RESPONSE" | sed '$d')
    if echo "$BODY" | grep -qi "opensearch"; then
      echo "opensearch"
    else
      echo "elasticsearch"
    fi
  else
    echo "unknown"
  fi
}

echo -e "\n${YELLOW}Detecting cluster type...${NC}"
CLUSTER_TYPE=$(detect_cluster_type)
echo "Cluster type: $CLUSTER_TYPE"
if [ "$CLUSTER_TYPE" = "unknown" ]; then
  echo -e "${RED}Failed to detect cluster type. Exiting.${NC}"
  exit 1
fi

if [ "$CLUSTER_TYPE" = "opensearch" ]; then
  ILM_POLICY_ENDPOINT="_plugins/_ism/policies"
  echo -e "${GREEN}Using OpenSearch ISM API${NC}"
else
  ILM_POLICY_ENDPOINT="_ilm/policy"
  echo -e "${GREEN}Using Elasticsearch ILM API${NC}"
fi

ILM_NAME="log-retention-${LOG_RETENTION_DAYS}days"

if [ "$CLUSTER_TYPE" = "elasticsearch" ]; then
  ILM_POLICY_JSON="{\"policy\":{\"phases\":{\"hot\":{\"min_age\":\"0ms\",\"actions\":{}},\"delete\":{\"min_age\":\"${LOG_RETENTION_DAYS}d\",\"actions\":{\"delete\":{}}}}}}"
else
  ILM_POLICY_JSON="{\"policy\":{\"description\":\"Policy to automatically delete log indices older than ${LOG_RETENTION_DAYS} days\",\"default_state\":\"hot\",\"states\":[{\"name\":\"hot\",\"actions\":[],\"transitions\":[{\"state_name\":\"delete\",\"conditions\":{\"min_index_age\":\"${LOG_RETENTION_DAYS}d\"}}]},{\"name\":\"delete\",\"actions\":[{\"delete\":{}}],\"transitions\":[]}]}}"
fi

echo -e "\n${YELLOW}Creating ILM/ISM policy (${LOG_RETENTION_DAYS}-day retention)...${NC}"
RESPONSE=$(curl -s -w '\n%{http_code}' -X PUT "$OPENSEARCH_URL/$ILM_POLICY_ENDPOINT/$ILM_NAME" \
  -H "Content-Type: application/json" -d "$ILM_POLICY_JSON")
check_response "$RESPONSE" || true

echo -e "\n${YELLOW}Creating index templates...${NC}"
INDEX_PATTERNS="applogs-* websocket-worker-logs-* graph-worker-logs-* scoring-worker-logs-* trending-worker-logs-* hashtag-worker-logs-* elasticsearch-sync-worker-logs-* media-worker-logs-* interaction-worker-logs-* chat-worker-logs-* expo-push-worker-logs-* webpush-worker-logs-* blog-autogen-worker-logs-*"
TEMPLATES_CREATED=0
for INDEX_PATTERN in $INDEX_PATTERNS; do
  TEMPLATE_NAME="${INDEX_PATTERN%-*}-template"
  if [ "$CLUSTER_TYPE" = "elasticsearch" ]; then
    INDEX_TEMPLATE_JSON="{\"index_patterns\":[\"$INDEX_PATTERN\"],\"template\":{\"settings\":{\"index.lifecycle.name\":\"$ILM_NAME\"}},\"priority\":200}"
  else
    INDEX_TEMPLATE_JSON="{\"index_patterns\":[\"$INDEX_PATTERN\"],\"template\":{\"settings\":{\"plugins.index_state_management.policy_id\":\"$ILM_NAME\"}},\"priority\":200}"
  fi
  RESPONSE=$(curl -s -w '\n%{http_code}' -X PUT "$OPENSEARCH_URL/_index_template/$TEMPLATE_NAME" -H "Content-Type: application/json" -d "$INDEX_TEMPLATE_JSON")
  if check_response "$RESPONSE"; then
    TEMPLATES_CREATED=$((TEMPLATES_CREATED + 1))
  fi
done
echo -e "${GREEN}✓ Templates created: $TEMPLATES_CREATED${NC}"

echo -e "\n${YELLOW}Applying policy to existing indices...${NC}"
INDICES_UPDATED=0
for INDEX_PATTERN in $INDEX_PATTERNS; do
  INDICES=$(curl -s "$OPENSEARCH_URL/_cat/indices/$INDEX_PATTERN?h=index" 2>/dev/null | grep -v '^$' || echo "")
  if [ -z "$INDICES" ]; then
    continue
  fi
  while IFS= read -r INDEX; do
    if [ -n "$INDEX" ]; then
      if [ "$CLUSTER_TYPE" = "elasticsearch" ]; then
        UPDATE_SETTINGS_JSON="{\"index.lifecycle.name\":\"$ILM_NAME\"}"
      else
        UPDATE_SETTINGS_JSON="{\"plugins.index_state_management.policy_id\":\"$ILM_NAME\"}"
      fi
      RESPONSE=$(curl -s -w '\n%{http_code}' -X PUT "$OPENSEARCH_URL/$INDEX/_settings" \
        -H "Content-Type: application/json" -d "$UPDATE_SETTINGS_JSON")
      if check_response "$RESPONSE"; then
        INDICES_UPDATED=$((INDICES_UPDATED + 1))
      fi
    fi
  done <<< "$INDICES"
done
if [ $INDICES_UPDATED -gt 0 ]; then
  echo -e "${GREEN}✓ Updated $INDICES_UPDATED existing indices${NC}"
else
  echo -e "${GREEN}✓ No existing indices to update (normal on first run)${NC}"
fi

echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}✓ Log retention configuration complete${NC}"
echo -e "${GREEN}========================================${NC}"
echo "  Policy: $ILM_NAME — logs older than ${LOG_RETENTION_DAYS} days will be automatically deleted."
