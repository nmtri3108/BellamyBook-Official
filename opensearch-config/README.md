# OpenSearch/Elasticsearch config (production)

Same layout as `dockerLocalENV/opensearch-config` (see that folder for full reference).

- **setup-log-retention-docker.sh** – Run by `elasticsearch-init` to apply N-day log retention (ILM/ISM) and index templates. Supports both Elasticsearch and OpenSearch (auto-detected). Applies policy to existing indices.
- **ilm-policy-5days.json** – Reference ILM/ISM policy (OpenSearch format); the script builds the policy dynamically.

**Configurable retention:** Set `LOG_RETENTION_DAYS` (default `5`) in `.env` or in the `elasticsearch-init` environment to control how long log indices are kept; older indices are deleted automatically to reduce data.

No manual steps required; `docker compose up` runs the init after Elasticsearch/OpenSearch is healthy.
