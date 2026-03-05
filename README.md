# Bellamy Book — Self-Host

**Run your own social network** with Docker. No source code required — use pre-built images, set your domain and secrets in `.env`, and go live.

<p align="center">
  <a href="https://bellamybook.com/landing"><img src="https://img.shields.io/badge/Landing-View_Product-2ea44f?style=for-the-badge" alt="Landing"></a>
  <a href="https://bellamybook.com"><img src="https://img.shields.io/badge/Demo-Try_Live-0969da?style=for-the-badge" alt="Demo"></a>
  <a href="https://docs.bellamybook.com"><img src="https://img.shields.io/badge/Docs-Documentation-8250df?style=for-the-badge" alt="Docs"></a>
  <a href="https://hub.docker.com/u/bellamy31"><img src="https://img.shields.io/badge/Docker_Hub-Images-2496ed?style=for-the-badge&logo=docker" alt="Docker Hub"></a>
  <a href="https://bellamybook.com/bellamy"><img src="https://img.shields.io/badge/Author_%26_Contact-Work_With_Us-6e7781?style=for-the-badge" alt="Author & Contact"></a>
  <a href="https://buymeacoffee.com/nmtri31082x"><img src="https://img.shields.io/badge/Buy_Me_a_Coffee-Support-ffdd00?style=for-the-badge&logo=buymeacoffee" alt="Buy Me a Coffee"></a>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Proprietary_%28Community_Edition%29-6e7781?style=flat-square" alt="License"></a>
  <a href="COPYRIGHT"><img src="https://img.shields.io/badge/Copyright-2025%E2%80%932026-6e7781?style=flat-square" alt="Copyright"></a>
</p>

---

## What is Bellamy Book?

**Bellamy Book** is a modern social network platform: posts, stories, messaging, video calls, blogs, search, and an admin panel. This repository is the **self-host kit**: everything you need to deploy it on your own server using Docker and Docker Compose.

| Link | Description |
|------|-------------|
| [**Landing**](https://bellamybook.com/landing) | Product overview and features |
| [**Demo**](https://bellamybook.com) | Try the app live |
| [**Docs**](https://docs.bellamybook.com) | Full documentation: installation, configuration, R2, SMTP, Turnstile, LiveKit, Google Login, and more |
| [**Docker Hub**](https://hub.docker.com/u/bellamy31) | Pre-built images (`bellamy31/bellamybook-*`) for self-hosting |
| [**Author & Contact**](https://bellamybook.com/bellamy) | Author page — get in touch for work or collaboration |
| [**Buy Me a Coffee**](https://buymeacoffee.com/nmtri31082x) | Support the project |

---

## Why self-host?

- **Your data, your server** — Full control over users and content.
- **Your domain** — Run at `app.yourdomain.com` with your branding.
- **Optional integrations** — MinIO or Cloudflare R2 for storage; SMTP, Turnstile, LiveKit, Google Login as you need.
- **One compose, one `.env`** — No build step; pull images, configure, run.

---

## Quick start (self-hosters)

### 1. Get this repo

Clone or download **this folder** (the self-host kit). You need: `docker-compose.yml`, `.env.example`, and the config directories (`traefik/`, `primary/`, `replica/`, `scripts/`, `opensearch-config/`). Create `.env` from `.env.example`; the other env files (`.env.frontend.example`, `.env.admin.example`) are for people who **build the app images from source** — you can ignore them.

### 2. Configure environment (3 env files)

This kit uses **three** environment files for different roles:

| File | Who uses it | Purpose |
|------|-------------|---------|
| **`.env`** (from `.env.example`) | **Self-hosters** | Runtime config: copy `.env.example` → `.env`, then set domain, secrets, DB passwords. Used by Docker Compose and all services. **This is the only file you need** when using pre-built images. |
| **`.env.frontend.example`** | **Image builders only** | Used when building the frontend Docker image from source. Not needed for self-hosting. |
| **`.env.admin.example`** | **Image builders only** | Used when building the admin Docker image from source. Not needed for self-hosting. |

**You only need `.env`.** Create it from `.env.example` and leave the other two files unchanged.

> **Read the documentation** for clear **step-by-step** instructions: [Self-Host with Pre-Built Images](https://docs.bellamybook.com/docs/self-host/installation/docker-publish) and [Environment Configuration](https://docs.bellamybook.com/docs/self-host/configuration/environment). The docs explain every variable, the configuration checklist, and optional services (JWT, storage, SMTP, Turnstile, LiveKit, Google Login, etc.).

**Quick setup (self-hosters):**

```bash
cp .env.example .env
```

Edit `.env` and set at least:

- **Docker images:** `DOCKER_REGISTRY=bellamy31`, `IMAGE_TAG=latest` (defaults; change if you use another publisher or tag).
- **Your domain:** `API_PUBLIC_URL`, `FRONTEND_PUBLIC_URL`, `ADMIN_PUBLIC_URL`, and all `TRAEFIK_*_HOST` to your hostnames.
- **Secrets:** Replace every `CHANGE_ME_*` — Postgres, Redis, MongoDB, Neo4j, RabbitMQ, MinIO, and **JWT** (`JwtSettings__Secret`, e.g. `openssl rand -base64 64`).

For full details and step-by-step guidance, see the [Environment](https://docs.bellamybook.com/docs/self-host/configuration/environment) and [configuration checklist](https://docs.bellamybook.com/docs/self-host/configuration/environment#configuration-checklist) in the docs.

### 3. Create MongoDB keyfile (required)

The stack uses a **MongoDB replica set** for the app and workers. MongoDB requires a **keyfile** for replica set authentication. You must create this file **before** your first `docker compose up`; the `mongo-keyfile-init` service copies it into a volume used by MongoDB.

**Where:** In the same directory as `docker-compose.yml` (the folder where you have this README).

**Commands (run once):**

```bash
# Run from the folder that contains docker-compose.yml
openssl rand -base64 756 > mongo-keyfile
chmod 600 mongo-keyfile
```

- **Name:** The file must be named exactly `mongo-keyfile` (compose mounts it as `./mongo-keyfile`).
- **Permissions:** `chmod 600` (read/write for owner only). Some setups use `chmod 400`; either is accepted by MongoDB.
- **Do not** commit `mongo-keyfile` to version control or share it; treat it as a secret.

If you skip this step, `mongo-keyfile-init` will fail with "Source keyfile /tmp/keyfile not found" and MongoDB will not start.

### 4. Run

```bash
docker compose pull
docker compose up -d
```

The **db-migration** service runs automatically as part of the stack: it starts after Postgres and MongoDB are healthy, applies schema and seed, then exits. No separate migration step or EF tools required. To re-run it (e.g. after upgrading to a new image tag), use: `docker compose run --rm db-migration`.

### 5. Access

- **With Traefik:** Use the hostnames in your `.env` (e.g. `https://app.yourdomain.com`). Point DNS to this server.
- **Without Traefik:** Frontend → http://localhost:8081, Admin → http://localhost:8084, API → http://localhost:5000.

Full step-by-step and optional services (R2, SMTP, Turnstile, Google Login, LiveKit, MinIO policies): **[Self-Host with Pre-Built Images](https://docs.bellamybook.com/docs/self-host/installation/docker-publish)**.

---

## Requirements

- **Docker** and **Docker Compose**
- **16GB+ RAM**, **8+ CPU** recommended for the full stack
- **Domain** (optional; you can test with localhost and ports)

---

## Configuration overview

For **step-by-step** setup of the three env files and all options, read the documentation: [Self-Host with Pre-Built Images](https://docs.bellamybook.com/docs/self-host/installation/docker-publish) and [Environment](https://docs.bellamybook.com/docs/self-host/configuration/environment).

| What | Docs |
|------|------|
| Environment variables, JWT, databases, storage | [Environment](https://docs.bellamybook.com/docs/self-host/configuration/environment) |
| JWT secret (required for login) | [JWT](https://docs.bellamybook.com/docs/self-host/configuration/jwt) |
| MinIO (default) or Cloudflare R2 | [Storage](https://docs.bellamybook.com/docs/self-host/configuration/storage), [R2 Setup](https://docs.bellamybook.com/docs/self-host/configuration/r2-setup) |
| MinIO bucket policies (security) | [Storage — MinIO security](https://docs.bellamybook.com/docs/self-host/configuration/storage#bucket-policies-security) |
| Mail (password reset, notifications) | [SMTP](https://docs.bellamybook.com/docs/self-host/configuration/smtp) |
| CAPTCHA on login/register | [Turnstile](https://docs.bellamybook.com/docs/self-host/configuration/turnstile) |
| Sign in with Google | [Google OAuth](https://docs.bellamybook.com/docs/self-host/configuration/google-oauth) |
| Voice and video calls | [LiveKit](https://docs.bellamybook.com/docs/self-host/configuration/livekit) |

---

## Updating

Set `IMAGE_TAG` in `.env` to the new tag (e.g. `v1.0.1`), then:

```bash
docker compose pull
docker compose up -d
```

---

## For image publishers (building and pushing images)

If you **build and push** the Docker images (e.g. from the full Bellamy Book source project):

- Use the **build and publish instructions** in that project. This folder is what you **distribute** to self-hosters: `docker-compose.yml`, `.env.example`, README, and config dirs — no source code.
- `.env.example` uses `DOCKER_REGISTRY=bellamy31` and `IMAGE_TAG=latest` by default. All services use `image: ${DOCKER_REGISTRY}/bellamybook-<service>:${IMAGE_TAG}`.
- Frontend and admin images read `API_PUBLIC_URL`, `FRONTEND_PUBLIC_URL`, `ADMIN_PUBLIC_URL`, `Minio__PublicUrl` from the user’s `.env` at container start, so one image set works for any domain.

---

## Image reference

Images follow `${DOCKER_REGISTRY}/bellamybook-<service>:${IMAGE_TAG}`. Default registry: `bellamy31`, tag: `latest`.

| Service | Image |
|---------|--------|
| db-migration (database app) | bellamybook-db-migration |
| api | bellamybook-api |
| frontend | bellamybook-frontend |
| admin | bellamybook-admin |
| websocket-worker | bellamybook-websocket-worker |
| chat-worker | bellamybook-chat-worker |
| interaction-worker | bellamybook-interaction-worker |
| scoring-worker | bellamybook-scoring-worker |
| trending-worker | bellamybook-trending-worker |
| graph-worker | bellamybook-graph-worker |
| hashtag-worker | bellamybook-hashtag-worker |
| elasticsearch-sync-worker | bellamybook-elasticsearch-sync-worker |
| media-processing-worker | bellamybook-media-processing-worker |
| expo-push-worker | bellamybook-expo-push-worker |
| webpush-worker | bellamybook-webpush-worker |
| blog-autogen-worker | bellamybook-blog-autogen-worker |

Infrastructure (PostgreSQL, Redis, MongoDB, Kafka, etc.) uses standard public images defined in `docker-compose.yml`.

---

## License

This self-host kit is released under a **proprietary license** (Bellamy Book Community Edition). You may self-host, deploy for internal or commercial use, and use the Software with up to 500 registered users under the terms of the license.

- **[LICENSE](LICENSE)** — Full license text (grant, restrictions, user limitation, disclaimer).
- **[COPYRIGHT](COPYRIGHT)** — Copyright and ownership notice.

Use beyond 500 registered users or other commercial arrangements may require a separate license. See [LICENSE](LICENSE) for details.

---

## Links

<p align="center">
  <a href="https://bellamybook.com/landing">Landing</a> ·
  <a href="https://bellamybook.com">Demo</a> ·
  <a href="https://docs.bellamybook.com">Documentation</a> ·
  <a href="https://hub.docker.com/u/bellamy31">Docker Hub</a> ·
  <a href="https://bellamybook.com/bellamy">Author & Contact</a> ·
  <a href="https://buymeacoffee.com/nmtri31082x">Buy Me a Coffee</a>
</p>
