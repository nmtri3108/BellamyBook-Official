# Test the self-host stack on your Mac (or any local machine)

Use this guide to run the **same** `dockerPublish` setup locally before deploying to a server. No extra server or cost needed — everything runs on your Mac.

---

## What you get

- **Frontend:** http://localhost:8081  
- **Admin:** http://localhost:8084  
- **API:** http://localhost:5000 (and http://localhost:5000/swagger for API docs)

Traefik is **not** started when using the local override, so you don’t need port 80/443 or a domain. You use the published ports directly.

---

## 1. Prerequisites

- **Docker Desktop** (or Docker Engine + Compose) on your Mac  
- **Enough resources:** 16GB+ RAM and 8+ CPU are recommended; you can try with less and scale down later  
- **Disk:** Several GB free for images and volumes  

---

## 2. Create `.env` from `.env.example`

```bash
cd dockerPublish
cp .env.example .env
```

---

## 3. Set local URLs and required secrets in `.env`

Edit `.env` and set at least the following.

### Public URLs (use localhost for local testing)

```bash
API_PUBLIC_URL=http://localhost:5000
FRONTEND_PUBLIC_URL=http://localhost:8081
ADMIN_PUBLIC_URL=http://localhost:8084
DOCS_PUBLIC_URL=https://docs.bellamybook.com
```

### Traefik hostnames (use `localhost` so CORS and rate-limit whitelist work)

```bash
TRAEFIK_API_HOST=localhost
TRAEFIK_FRONTEND_HOST=localhost
TRAEFIK_ADMIN_HOST=localhost
TRAEFIK_DOCS_HOST=docs.bellamybook.com
TRAEFIK_DASHBOARD_HOST=localhost
TRAEFIK_DASHBOARD_IP=127.0.0.1
```

### Replace every `CHANGE_ME_*` with real values

Use strong random values for production; for local testing you can use simple (but still unique) passwords. **JWT is required** for login to work.

| Variable | Example (local only) | Production |
|----------|----------------------|------------|
| `POSTGRES_PASSWORD` | e.g. `local_pg_Secret1` | Strong random |
| `REPLICATION_PASSWORD` | e.g. `local_rep_Secret1` | Strong random |
| `REDIS_PASSWORD` | e.g. `local_redis_Secret1` | Strong random |
| `MONGO_ROOT_PASSWORD` | e.g. `local_mongo_Secret1` | Strong random |
| `RABBITMQ_DEFAULT_PASS` | e.g. `local_rabbit_Secret1` | Strong random |
| `RABBITMQ_ERLANG_COOKIE` | e.g. `local_erlang_cookie_secret` | Strong random |
| `NEO4J_AUTH` | `neo4j/local_neo4j_Secret1` | Strong random |
| `MINIO_ROOT_USER` | e.g. `minioadmin` | Your choice |
| `MINIO_ROOT_PASSWORD` | e.g. `minioadmin_secret` | Strong random |
| **`JwtSettings__Secret`** | **Required** — e.g. `openssl rand -base64 64` | Strong random, min 32 chars |
| `DatabaseAppAesKey` | e.g. `openssl rand -base64 32` | Strong random |
| `Turnstile__SecretKey` / `Turnstile__SiteKey` | Optional for local: get free keys at [Cloudflare Turnstile](https://dash.cloudflare.com/?to=/:account/turnstile) for `localhost` | Your keys |

Quick JWT secret (run in terminal):

```bash
openssl rand -base64 64
```

Paste the output into `JwtSettings__Secret=` in `.env`.

---

## 4. Create MongoDB keyfile (required)

The stack uses a MongoDB replica set; MongoDB requires a keyfile. Run **once** in the same directory as `docker-compose.yml`:

```bash
openssl rand -base64 756 > mongo-keyfile
chmod 600 mongo-keyfile
```

Do **not** commit `mongo-keyfile` to git.

---

## 5. Start the stack **without** Traefik (local override)

Use the local override so Traefik is not started (no port 80/443, less resource use):

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml pull
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

To follow logs instead of detaching:

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml up
```

---

## 6. Wait for services and migration

- **db-migration** runs automatically after Postgres and MongoDB are healthy, then exits.  
- First startup can take several minutes (Kafka, Elasticsearch, MongoDB replica set, etc.).

Check that containers are up:

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml ps
```

Check API health:

```bash
curl -s http://localhost:5000/api/health
```

---

## 7. Open the app

- **Frontend (main app):** http://localhost:8081  
- **Admin panel:** http://localhost:8084  
- **API Swagger:** http://localhost:5000/swagger  

Register a user and log in. If login fails, double-check `JwtSettings__Secret` and that `API_PUBLIC_URL` / `FRONTEND_PUBLIC_URL` in `.env` are exactly `http://localhost:5000` and `http://localhost:8081`.

---

## 8. Stop and clean up (optional)

Stop everything:

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml down
```

To remove volumes as well (full reset, deletes DBs):

```bash
docker compose -f docker-compose.yml -f docker-compose.local.yml down -v
```

---

## 9. When you’re ready for a real server

1. Copy the same `dockerPublish` folder (or clone the repo) on the server.  
2. Create `.env` from `.env.example` and set **real** domain URLs and **strong** secrets.  
3. Create `mongo-keyfile` on the server (same commands as above).  
4. Run **without** the local override so Traefik starts:

   ```bash
   docker compose pull
   docker compose up -d
   ```

5. Point DNS for your domain to the server and configure Traefik/HTTPS as in the main [README](README.md) and docs.

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| **Login doesn’t work** | `JwtSettings__Secret` set (min 32 chars); `API_PUBLIC_URL` and `FRONTEND_PUBLIC_URL` match how you open the app (e.g. `http://localhost:5000`, `http://localhost:8081`). |
| **CORS errors in browser** | `FRONTEND_PUBLIC_URL`, `ADMIN_PUBLIC_URL`, and `TRAEFIK_*_HOST` in `.env` should be `localhost` (no port in host for CORS). |
| **mongo-keyfile not found** | Create `mongo-keyfile` in the same directory as `docker-compose.yml` and `chmod 600 mongo-keyfile`. |
| **Containers exit or unhealthy** | Run `docker compose -f docker-compose.yml -f docker-compose.local.yml logs -f` and check the failing service (often Postgres, MongoDB, or Kafka need more time on first start). |
| **Out of memory** | In Docker Desktop, increase Memory (e.g. 8–16GB). You can also comment out optional services in `docker-compose.yml` if needed. |

You can test the full self-host flow on your Mac, then switch to a server when you’re ready — no extra server cost until then.
