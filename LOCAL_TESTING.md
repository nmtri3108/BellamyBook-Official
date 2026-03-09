# Test the self-host stack on your Mac (or any local machine)

Use this guide to run the **same** `dockerPublish` setup locally before deploying to a server. No extra server or cost needed — everything runs on your Mac.

**Important:** The compose and Postgres setup are **aligned with dockerProd**. To avoid “database MigrationDb does not exist” or “no pg_hba.conf entry for replication”, Postgres init runs only when the primary volume is empty. Do a **clean run**: `docker compose -f docker-compose.yml -f docker-compose.local.yml down -v` then `up -d`.

---

## What you get

- **Frontend:** http://localhost:8081  
- **Admin:** http://localhost:8084  
- **API + WebSocket (SignalR):** http://localhost:5000 (API, Swagger, notification/chat hubs on same host)
- **MinIO:** http://localhost:9000 (S3 API), http://localhost:9001 (Console). Set `Minio__PublicUrl=http://localhost:9000` in `.env` so the frontend can load media.

Traefik is **not** started when using the local override. An **api-gateway** (nginx) routes `/api`, `/swagger`, `/health` to the API and `/hubs/*` to the WebSocket and Chat workers, so real-time features work without Traefik. You don’t need port 80/443 or a domain. You use the published ports directly.

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
# MinIO: so frontend can load avatars/post media (required when using Storage__Provider=MinIO)
Minio__PublicUrl=http://localhost:9000
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
| **`POSTGRES_USER`** | **Must be `postgres`** (not `root`; root is for MongoDB) | `postgres` |
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

---

## 7. Verify and open the app

**Quick checks (use your API port if you set `API_PORT`, e.g. 5001):**

```bash
# API health (replace 5001 with 5000 if using default)
curl -s http://localhost:5001/api/health

# Or from dockerPublish dir:
docker compose -f docker-compose.yml -f docker-compose.local.yml ps
```

| Check | URL | Expected |
|-------|-----|----------|
| API health | http://localhost:5001/api/health | JSON with status |
| API Swagger | http://localhost:5001/swagger | API docs UI |
| Admin panel | http://localhost:8084 | Admin login |
| Frontend (main app) | http://localhost:8081 | App home / sign-in |

**Default admin account** (if seeded): **Email** `Admin@gmail.com`, **Password** `Admin123@`. **Change this password immediately** after first login (Admin Panel → Profile or account settings).

Register a user and log in. If login fails, double-check `JwtSettings__Secret` and that `API_PUBLIC_URL` / `FRONTEND_PUBLIC_URL` in `.env` match the URLs you use (e.g. `http://localhost:5001` and `http://localhost:8081`). If the frontend container is **Restarting**, run `docker compose -f docker-compose.yml -f docker-compose.local.yml logs frontend` to see the error.

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

## Why `docker-compose.local.yml` only (no app code change)

Code is the same for local and production. The difference is **environment**:

| | Production / server | dockerPublish local (this guide) |
|---|---------------------|-----------------------------------|
| **Reverse proxy** | Traefik (HTTPS, one host). Routes `/api`, `/hubs/*` to API/workers. | **api-gateway** (nginx) on `API_PORT`; same path routing, HTTP. |
| **API host port** | Not exposed; Traefik talks to `api` by name. | Not exposed; api-gateway talks to `api` by name. |
| **API env** | `ASPNETCORE_ENVIRONMENT=Production`. Cookie `Secure=true`, no refresh token in body. | **`ASPNETCORE_ENVIRONMENT=Local`** in override → cookie `Secure=false`, refresh token in body → admin/frontend login stays over HTTP. |
| **CSP (frontend)** | HTTPS → `wss:` enough for SignalR. | HTTP → need **`ws:`** in `connect-src` (in frontend image nginx.conf) for `ws://localhost:API_PORT`. |

So: **no backend/frontend logic change**. Only compose override + frontend CSP so the same code runs on both.

---

## Debug checklist (stable local run)

1. **Always use both compose files:**  
   `docker compose -f docker-compose.yml -f docker-compose.local.yml up -d`
2. **API port (e.g. 5002):** Must be bound by **api-gateway**, not the api container. Check: `docker ps` — the api-gateway container should show `0.0.0.0:5002->80/tcp`; the api container should **not** expose that port.
3. **SignalR negotiate:**  
   `curl -s -o /dev/null -w "%{http_code}" "http://localhost:5002/hubs/notification/negotiate?negotiateVersion=1"` should return **401** (not 404). If 404, the request is hitting the API instead of the api-gateway.
4. **Admin login (stays logged in):** API must run with **Local** env (override sets `ASPNETCORE_ENVIRONMENT: Local`). Recreate api to apply: `docker compose -f docker-compose.yml -f docker-compose.local.yml up -d api --force-recreate`.
5. **Frontend notification (SignalR):** CSP must allow `ws:`; if you rebuild the frontend image, use one that has `connect-src ... ws: wss:` in nginx.conf.

---

## Clean start (fix password / replication / MongoDB / Neo4j errors)

If you see **"password authentication failed for user postgres"**, **"no pg_hba.conf entry for replication"**, or **MongoDB/Neo4j auth failures**, the existing data volumes were created with **different credentials** than in your current `.env`. Do a full reset (this deletes all DB data):

```bash
cd dockerPublish
docker compose -f docker-compose.yml -f docker-compose.local.yml down -v
docker compose -f docker-compose.yml -f docker-compose.local.yml up -d
```

Wait a few minutes, then check: `logs postgres-replica` (should show "pg_basebackup succeeded"). Primary init scripts (01, 02) run only on first start (empty volume).

---

## Troubleshooting

| Issue | What to check |
|-------|----------------|
| **Login doesn’t work** | `JwtSettings__Secret` set (min 32 chars); `API_PUBLIC_URL` and `FRONTEND_PUBLIC_URL` match how you open the app (e.g. `http://localhost:5000`, `http://localhost:8081`). |
| **CORS errors in browser** | `FRONTEND_PUBLIC_URL`, `ADMIN_PUBLIC_URL`, and `TRAEFIK_*_HOST` in `.env` should be `localhost` (no port in host for CORS). Compose passes `Frontend__CorsOrigins__*` so API and SignalR workers allow your frontend/admin origins. |
| **SignalR / WebSocket not connecting** | Frontend uses `config.js` (from `API_PUBLIC_URL`). Ensure `api`, `websocket-worker`, and `chat-worker` have CORS origins set (they get `Frontend__CorsOrigins__0` etc. from compose). Recreate: `docker compose -f docker-compose.yml -f docker-compose.local.yml up -d api websocket-worker chat-worker --force-recreate`. Then hard-refresh the app. |
| **mongo-keyfile not found** | Create `mongo-keyfile` in the same directory as `docker-compose.yml` and `chmod 600 mongo-keyfile`. |
| **Containers exit or unhealthy** | Run `docker compose -f docker-compose.yml -f docker-compose.local.yml logs -f` and check the failing service (often Postgres, MongoDB, or Kafka need more time on first start). |
| **"postgres-primary is unhealthy"** | Healthcheck matches dockerProd (`pg_isready` on default DB). Ensure `POSTGRES_USER=postgres` in `.env`. If it still fails, do a **clean start**: `docker compose down -v` then `up -d`. |
| **Port 5000 or 5001 already in use** | Free the port: `lsof -i :5000` or `lsof -i :5001`, then stop that process. Or use another port: in `.env` set `API_PORT=5002` and `API_PUBLIC_URL=http://localhost:5002` (api-gateway binds `API_PORT`). |
| **Out of memory** | In Docker Desktop, increase Memory (e.g. 8–16GB). You can also comment out optional services in `docker-compose.yml` if needed. |
| **Postgres: "Role \"root\" does not exist" / "password authentication failed for user root"** | Set `POSTGRES_USER=postgres` in `.env` (not `root`; root is for MongoDB). |
| **Postgres: "password authentication failed for user postgres"** | The primary data volume was created with a **different** `POSTGRES_PASSWORD` than in your current `.env`. Do a **clean start**: `docker compose down -v` (removes volumes), then `up -d` again so Postgres is re-initialized with the passwords in `.env`. |
| **Postgres replica / pg_basebackup / "no pg_hba.conf entry for replication"** | Do a **clean start** (`down -v`, then `up -d`). Primary init (01, 02) runs only when the volume is new; then replica can connect. |
| **MongoDB or Neo4j auth failures** | Same cause: volumes were created with different credentials. Do a **clean start** (`docker compose down -v`, then `up -d`) so MongoDB and Neo4j are re-created with the passwords in your current `.env`. |
| **Neo4j connection errors (app)** | In `.env`, set `Neo4j__Password` to the same value as the password in `NEO4J_AUTH` (e.g. `NEO4J_AUTH=neo4j/mypass` → `Neo4j__Password=mypass`). |

You can test the full self-host flow on your Mac, then switch to a server when you’re ready — no extra server cost until then.
