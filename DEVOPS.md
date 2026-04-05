# Fundose — DevOps

**Purpose:** Deployment context, architecture, and operations (aligned with [Crator Labs DEVOPS](../crator-labs/DEVOPS.md) patterns).

---

## 1. Projects overview

| Project | Path | Stack | Prod container | Internal port |
|--------|------|-------|----------------|---------------|
| **fundose-backend** | `fundose-backend/` | Django 4, Gunicorn, PostgreSQL 16, Redis 7 | `fundose-backend` | 8000 |
| **fundose-fe** | `fundose-fe/` | Next.js 12 (Pages), standalone Node image | `fundose-fe` | 3000 |

Submodules of parent repo `fundose`. After clone: `git submodule update --init --recursive`.

---

## 2. Architecture

### 2.1 How it connects

```
Internet
  │
  └── fundose.in ─────────────► infra nginx (TLS termination)
                                    ├── /auth, /players, /quiz, /admin, /static → fundose-backend:8000
                                    ├── /_next/* → fundose-fe:3000
                                    └── / → fundose-fe:3000
```

All app containers attach to **`infra_net`**. Infra nginx resolves them by name (`resolver 127.0.0.11`), same as Crator Labs.

### 2.2 Per-repo layout

```
fundose-backend/ / fundose-fe/
├── Dockerfile              # Production image
├── Dockerfile.dev        # Dev (hot reload)
├── docker-compose.yml    # Prod: joins infra_net, external volume
├── docker-compose.dev.yml
└── scripts/              # Backend only: entrypoint.sh
```

Parent repo:

```
deploy/nginx/             # Infra nginx (prod + local)
scripts/
├── bootstrap.sh          # Volume, network, nginx files, hosts (dev)
├── bootstrap-nginx-only.sh
├── up-stack-dev.sh
└── up-stack-prod.sh
```

### 2.3 Docker — production

| Service | Image flow | Container | Published host port |
|---------|------------|-----------|---------------------|
| **fundose-backend** | Multi-stage Python 3.10-slim; Gunicorn | `fundose-backend` | None (only `5434:5432` on Postgres) |
| **fundose-fe** | Multi-stage Node 18 Alpine; `next build` + standalone | `fundose-fe` | None |

Postgres data: **external** named volume `fundose-backend-postgres` (created by `scripts/bootstrap.sh`).

### 2.4 Docker — development

| Service | Dockerfile.dev | Container | App port | Hot reload |
|---------|----------------|-----------|----------|------------|
| **fundose-backend** | Python 3.10, `runserver` | `fundose-backend-dev` | 8000 | Source bind-mount |
| **fundose-fe** | Node 18, `next dev` | `fundose-fe-dev` | 3000 | Source + `node_modules` volume |

Access via **`http://fundose.local`** once infra nginx is configured (not raw `localhost:3000`), mirroring Crator’s `.local` workflow.

---

## 3. Nginx

### 3.1 Production (server)

| File | Domain | Role |
|------|--------|------|
| `deploy/nginx/fundose.in.conf` | fundose.in, www → redirect | TLS + `set $fundose_be` / `$fundose_fe` + include snippet |
| `deploy/nginx/_fundose-locations.conf` | (snippet) | Proxies Django API paths and Next.js |

TLS paths assume Let’s Encrypt: `/etc/letsencrypt/live/fundose.in/`. Adjust `server_name` and cert paths if your domain differs.

### 3.2 Local development

| File | Domain | Upstream containers |
|------|--------|---------------------|
| `deploy/nginx/fundose.local.conf` | fundose.local | `fundose-backend-dev:8000`, `fundose-fe-dev:3000` |

Add to `/etc/hosts` (or run `bash scripts/bootstrap.sh --dev`, which appends it):

```
127.0.0.1  fundose.local
```

### 3.3 Host paths (infra container mounts)

Same convention as Crator:

- Server configs: `/opt/nginx/conf.d/`
- Snippets: `/opt/nginx/snippets/` (must map to `/etc/nginx/snippets/` inside the nginx container so `include /etc/nginx/snippets/_fundose-locations.conf` works)

---

## 4. Volume and network

| Name | Type | Created by |
|------|------|------------|
| `fundose-backend-postgres` | Docker volume (external in compose) | `scripts/bootstrap.sh` |
| `infra_net` | Docker network (external) | `scripts/bootstrap.sh` |

**Note:** If another project on the same host already created `infra_net`, bootstrap skips creation and reuses it.

---

## 5. Bootstrap scripts

### 5.1 `scripts/bootstrap.sh`

```bash
bash scripts/bootstrap.sh           # prod: fundose.in.conf + volume + network + snippet
bash scripts/bootstrap.sh --dev     # dev: fundose.local.conf + hosts entry + volume + network + snippet
```

### 5.2 `scripts/bootstrap-nginx-only.sh`

Refreshes only nginx files under `/opt/nginx` after you edit `deploy/nginx/*` (no volume/network).

### 5.3 `scripts/up-stack-dev.sh` / `scripts/up-stack-prod.sh`

Brings up **both** submodules with the matching compose files (expects `.env` in `fundose-backend` and bootstrap already run for prod/dev as appropriate).

---

## 6. First-time setup

### 6.1 Backend environment

```bash
cd fundose-backend
cp .env.example .env
# Set SECRET_KEY, ENC_KEY, DATABASE_URL, POSTGRES_*, DEBUG, etc.
```

`ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` are comma-separated lists (no spaces), overridable via `.env`.

### 6.2 Local dev (summary)

```bash
# From monorepo root
bash scripts/bootstrap.sh --dev
cd fundose-backend && cp -n .env.example .env && cd ..
bash scripts/up-stack-dev.sh
# Reload infra nginx: nginx -t && nginx -s reload
# Open http://fundose.local
```

### 6.3 Production (summary)

1. Issue TLS certs for `fundose.in` (e.g. certbot).
2. `bash scripts/bootstrap.sh` on the server.
3. Ensure infra nginx mounts `/opt/nginx` correctly.
4. `fundose-backend`: `.env` with production secrets.
5. `fundose-fe`: image built with `NEXT_PUBLIC_API_BASE_URL=""` (default in `docker-compose.yml`) so the browser calls same-origin paths (`/auth/`, …).
6. `bash scripts/up-stack-prod.sh`
7. `nginx -t` && `nginx -s reload` on infra.

---

## 7. Frontend API base URL

| Scenario | `NEXT_PUBLIC_API_BASE_URL` |
|----------|----------------------------|
| Same host as nginx (this stack) | `""` (empty) at **build** time |
| Legacy `api.fundose.in` | `https://api.fundose.in` |

Unset at build time defaults to `https://api.fundose.in` in code for backward compatibility.

---

## 8. Quick reference

```bash
# Logs
docker logs -f fundose-backend
docker logs -f fundose-fe

# Redeploy one service
cd fundose-backend && docker compose up --build -d
cd fundose-fe && docker compose up --build -d
```

---

## 9. File index

| Path | Description |
|------|-------------|
| `deploy/nginx/fundose.in.conf` | Production server block |
| `deploy/nginx/fundose.local.conf` | Local HTTP server block |
| `deploy/nginx/_fundose-locations.conf` | Shared `location` map |
| `fundose-backend/Dockerfile` | Prod API image |
| `fundose-backend/Dockerfile.dev` | Dev API image |
| `fundose-backend/docker-compose*.yml` | DB + Redis + API |
| `fundose-backend/scripts/entrypoint.sh` | Wait for Postgres → migrate → collectstatic |
| `fundose-fe/Dockerfile` | Next standalone prod |
| `fundose-fe/Dockerfile.dev` | Next dev server |

---

## 10. Backend changes for containers

- **Gunicorn + WhiteNoise** for production static files and WSGI serving.
- **`ALLOWED_HOSTS` / `CSRF_TRUSTED_ORIGINS`** driven from `.env` (comma-separated) with sensible defaults including `fundose.local` and container names.
- **`core/constants.py`**: Redis host/port from env; safe fallback if Redis is unreachable at startup.

---

*Last updated: 2026-04-06*
