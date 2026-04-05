# Fundose — DevOps

**Purpose:** Deployment context for **fundose.in** (Next.js) and **api.fundose.in** (Django) on separate subdomains with **separate TLS certificates**.

---

## 1. Projects overview

| Project | Path | Public host | Container | Internal port |
|--------|------|-------------|-----------|---------------|
| **fundose-fe** | `fundose-fe/` | **fundose.in** | `fundose-fe` | 3000 |
| **fundose-backend** | `fundose-backend/` | **api.fundose.in** | `fundose-backend` | 8000 |

Submodules of parent repo `fundose`. After clone: `git submodule update --init --recursive`.

---

## 2. Architecture

```
Internet
  ├── fundose.in      ──► infra nginx ──► fundose-fe:3000
  └── api.fundose.in  ──► infra nginx ──► fundose-backend:8000   (all paths → Gunicorn)
```

- **Two Let’s Encrypt certificates:** `fundose.in` (and `www`) · `api.fundose.in`
- Nginx vhosts live **in each repo** under `deploy/nginx/`; `scripts/bootstrap.sh` copies them to `/opt/nginx/conf.d/`.
- App containers use **`infra_net`**; nginx uses Docker DNS (`resolver 127.0.0.11`).

---

## 3. Nginx files (by repo)

| Repo | File | Domain | Upstream |
|------|------|--------|----------|
| **fundose-fe** | `deploy/nginx/fundose.in.conf` | fundose.in, www | `fundose-fe:3000` |
| **fundose-fe** | `deploy/nginx/fundose.local.conf` | fundose.local | `fundose-fe-dev:3000` |
| **fundose-backend** | `deploy/nginx/api.fundose.in.conf` | api.fundose.in | `fundose-backend:8000` |
| **fundose-backend** | `deploy/nginx/api.fundose.local.conf` | api.fundose.local | `fundose-backend-dev:8000` |

**Host install path:** `/opt/nginx/conf.d/` (mounted into the infra nginx container). No shared snippet: the API vhost is a single `location /` proxy.

---

## 4. Bootstrap (`scripts/bootstrap.sh`)

Creates **`fundose-backend-postgres`** and **`infra_net`** if missing, then copies **both** vhosts from the submodules.

```bash
bash scripts/bootstrap.sh           # fundose.in.conf + api.fundose.in.conf
bash scripts/bootstrap.sh --dev     # *.local.conf + /etc/hosts (fundose.local, api.fundose.local)
```

Re-run anytime to refresh nginx files after editing configs in the submodules.

---

## 5. TLS (Let’s Encrypt) — first time

**Important:** The **api** vhost references `/etc/letsencrypt/live/api.fundose.in/` before that cert exists. Issue **api** first using HTTP-only, then restore the full vhost.

1. **Temporary HTTP-only** for `api.fundose.in` (port 80 only, `/.well-known/acme-challenge/` → `/var/www/certbot`), then `nginx -t` && reload.
2. **Certbot** (from `~/infra`, same stack as Crator):

   ```bash
   cd /home/deploy/infra
   docker compose run --rm --entrypoint certbot certbot certonly \
     --webroot -w /var/www/certbot -d api.fundose.in \
     --agree-tos --non-interactive --register-unsafely-without-email
   ```

3. **`bash scripts/bootstrap.sh`** (from monorepo root) to copy the **full** `api.fundose.in.conf`, then reload nginx.

4. Repeat the same pattern for **fundose.in** if that cert is not present yet (separate cert).

**Cloudflare:** Ensure HTTP challenges reach origin (no rule that blocks `/.well-known/acme-challenge/` on the relevant host).

---

## 6. Frontend API URL

| Environment | `NEXT_PUBLIC_API_BASE_URL` |
|-------------|----------------------------|
| Production compose | `https://api.fundose.in` (set in `fundose-fe/docker-compose.yml`) |
| Dev compose | `http://api.fundose.local` |

Django **ALLOWED_HOSTS** / **CSRF_TRUSTED_ORIGINS** must include `api.fundose.in` (and local names for dev). See `fundose-backend/.env.example`.

---

## 7. Docker quick reference

```bash
cd fundose-backend && docker compose up --build -d
cd fundose-fe && docker compose up --build -d
```

Dev: `docker compose -f docker-compose.dev.yml up --build -d` in each repo.

---

## 8. Volume and network

| Name | Created by |
|------|------------|
| `fundose-backend-postgres` | `scripts/bootstrap.sh` |
| `infra_net` | `scripts/bootstrap.sh` |

---

*Last updated: 2026-04-06*
