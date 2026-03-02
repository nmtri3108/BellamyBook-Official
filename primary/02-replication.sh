#!/bin/bash
# Enable replication on primary and create replication user (myuser).
# Requires REPLICATION_PASSWORD in environment (set in docker-compose for postgres-primary).
set -e
export PGPASSWORD="$POSTGRES_PASSWORD"
# Enable replication settings
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-'EOSQL'
  ALTER SYSTEM SET wal_level = replica;
  ALTER SYSTEM SET max_wal_senders = 10;
  ALTER SYSTEM SET hot_standby = on;
  ALTER SYSTEM SET listen_addresses = '*';
  ALTER SYSTEM SET wal_keep_size = '64MB';
EOSQL
# Create replication user (password from env; safe when REPLICATION_PASSWORD has no single quotes)
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE ROLE myuser WITH REPLICATION LOGIN ENCRYPTED PASSWORD '${REPLICATION_PASSWORD}';"
# Allow replication in pg_hba (append; postgres image already has base rules)
echo 'host    replication     all             0.0.0.0/0               scram-sha-256' >> /var/lib/postgresql/data/pg_hba.conf
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c 'SELECT pg_reload_conf();'
unset PGPASSWORD
