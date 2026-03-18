#!/usr/bin/env bash
set -e

if [ -z "${REPLICATION_PASSWORD:-}" ]; then
  echo "ERROR: REPLICATION_PASSWORD must be set." >&2
  exit 1
fi

export PGPASSWORD="${REPLICATION_PASSWORD}"

echo "Waiting for primary to accept connections..."
until pg_isready -h postgres-primary -p 5432; do
  sleep 2
done

echo "Waiting for replication user myuser (primary init may still be running)..."
for i in $(seq 1 60); do
  rm -rf /var/lib/postgresql/data/*
  if gosu postgres pg_basebackup -h postgres-primary -D /var/lib/postgresql/data -U myuser -Fp -Xs -P -R; then
    echo "pg_basebackup succeeded."
    break
  fi
  echo "Attempt ${i}/60: basebackup failed, retrying in 5s..."
  sleep 5
done

if [ ! -f /var/lib/postgresql/data/postgresql.conf ]; then
  echo "ERROR: pg_basebackup did not succeed after 60 attempts (check REPLICATION_PASSWORD and primary init)" >&2
  exit 1
fi

cp /tmp/pg_hba.conf /var/lib/postgresql/data/pg_hba.conf
echo "listen_addresses='*'" >> /var/lib/postgresql/data/postgresql.conf
chown -R postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

exec gosu postgres postgres
