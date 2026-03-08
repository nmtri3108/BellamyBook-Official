# Make sure Traefik works when you deploy

When you deploy to a **Linux server** (not local testing), Traefik is the reverse proxy that routes traffic to the app. Follow this checklist so it works.

---

## 1. Use the right compose command (no local override)

On the server, **do not** use `docker-compose.local.yml`. That file is only for local testing and leaves Traefik stopped.

```bash
docker compose pull
docker compose up -d
```

This starts Traefik and all services. Traefik will listen on **80** (HTTP) and **443** (HTTPS).

---

## 2. Set your real hostnames in `.env`

Traefik routes by **hostname**. Every `TRAEFIK_*_HOST` in `.env` must be set to the hostnames that will point to **this server** (no `https://`, no port).

**Check before starting:** from the `dockerPublish` folder run:

```bash
./scripts/check-traefik-env.sh
```

This warns if `TRAEFIK_API_HOST`, `TRAEFIK_FRONTEND_HOST`, or `TRAEFIK_ADMIN_HOST` are missing or still contain placeholders like `your-domain`.

| Variable | Example | Must match |
|----------|---------|------------|
| `TRAEFIK_API_HOST` | `api.yourdomain.com` | DNS for API |
| `TRAEFIK_FRONTEND_HOST` | `app.yourdomain.com` | DNS for main app |
| `TRAEFIK_ADMIN_HOST` | `admin.yourdomain.com` | DNS for admin panel |
| `TRAEFIK_DASHBOARD_HOST` | `dashboard.yourdomain.com` (optional) | If you expose Traefik dashboard |
| `TRAEFIK_DASHBOARD_IP` | Your server’s public IP | So `http://YOUR_IP:8080` works for dashboard without a hostname |

Also set the **public URLs** (they should match the same hostnames):

```bash
API_PUBLIC_URL=https://api.yourdomain.com
FRONTEND_PUBLIC_URL=https://app.yourdomain.com
ADMIN_PUBLIC_URL=https://admin.yourdomain.com
```

If you leave `TRAEFIK_*_HOST` as `api.your-domain.com` or `bellamybook.com`, Traefik will only respond to those hostnames, so your domain will get 404 or wrong routing.

---

## 3. Point DNS to the server

For each hostname you use:

- **A (or AAAA)** record → this server’s **public IP**  
  Example: `api.yourdomain.com` → `203.0.113.10`

Wait for DNS to propagate before testing. You can check with:

```bash
dig +short api.yourdomain.com
```

---

## 4. Open ports on the server

Traefik needs:

- **80** (HTTP)
- **443** (HTTPS)

Optional:

- **8080** – Traefik dashboard (only if you use `TRAEFIK_DASHBOARD_IP` or a dashboard hostname)

On the server:

- **Firewall:** allow 80, 443 (and 8080 if you use the dashboard).
- **Cloud / security groups:** allow inbound 80 and 443 to this host.

---

## 5. HTTPS (recommended for production)

By default, Traefik is configured with HTTP (80) and HTTPS (443) entrypoints, but **no TLS certificate provider** is enabled. So 443 will accept connections but won’t serve a valid cert until you configure one.

**Option A – Let’s Encrypt (Traefik on the server)**

1. In `traefik/traefik.yml`, uncomment the `certificatesResolvers` block and set your email.
2. Ensure the `traefik_letsencrypt` volume exists (it’s in the compose file) and that the file where ACME stores certs has correct permissions (e.g. `chmod 600` if you use a file).
3. Add the resolver to your routers (e.g. `certificatesResolvers: letsencrypt`) on the HTTPS routers, or use dynamic config so Traefik requests certs for your hostnames.

**Option B – Cloudflare Tunnel**

- Run the tunnel in front of the server; Cloudflare terminates HTTPS.
- Point the tunnel to `http://traefik:80` or to the host’s 80/443 as per Cloudflare docs. No need to enable Let’s Encrypt in Traefik in that case.

**Option C – Another reverse proxy in front**

- Terminate HTTPS on nginx/HAProxy/Caddy and proxy to Traefik on 80 (or 443). Then Traefik itself doesn’t need TLS.

---

## 6. Quick check that Traefik is working

1. **Containers:**  
   `docker compose ps`  
   Ensure `traefik`, `api`, `frontend`, `admin` are running.

2. **Traefik sees the app:**  
   Open the dashboard (if you use it):  
   `http://YOUR_SERVER_IP:8080` (and set `TRAEFIK_DASHBOARD_IP` to that IP in `.env`).  
   Check that HTTP routers exist for api, frontend, admin with the correct hostnames.

3. **HTTP (port 80):**  
   From your machine:  
   `curl -H "Host: app.yourdomain.com" http://YOUR_SERVER_IP/`  
   You should get the frontend (or a redirect), not a connection error or Traefik “404”.

4. **Real hostname:**  
   Once DNS is pointing to the server:  
   `curl -I https://app.yourdomain.com/`  
   (or `http://` if you haven’t set up HTTPS yet). You should get a 200 or 301/302, not 404.

---

## Summary

| Step | Action |
|------|--------|
| 1 | On server use `docker compose up -d` (no `-f docker-compose.local.yml`) |
| 2 | Set all `TRAEFIK_*_HOST` and `*_PUBLIC_URL` in `.env` to **your** domain hostnames |
| 3 | Point DNS (A/AAAA) for those hostnames to this server |
| 4 | Open ports 80 and 443 (and 8080 if using dashboard) |
| 5 | Configure HTTPS (Let’s Encrypt, Cloudflare, or another proxy) |

If you do these, Traefik will route traffic correctly when users deploy to their own server.
