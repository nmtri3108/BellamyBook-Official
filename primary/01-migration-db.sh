#!/bin/bash
# Create MigrationDb if it does not exist (idempotent)
# Runs as part of postgres-primary init; uses POSTGRES_USER and POSTGRES_DB from env.
set -e
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -tc "SELECT 1 FROM pg_database WHERE datname = 'MigrationDb'" | grep -q 1 || \
  psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c 'CREATE DATABASE "MigrationDb" OWNER postgres;'
