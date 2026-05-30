# portfolio-deploy

Deployment repository for **d4m13n.dev**. Runs the whole site — Next.js frontend,
PocketBase backend, and a Caddy reverse proxy with automatic HTTPS — as a single
Docker Compose stack on any Linux VM. **No Kubernetes.**

The application code lives in the [`portfolio_v2`](https://github.com/D4M13N-D3V/portfolio_v2)
repository, wired in here as a **git submodule** at `./portfolio`. This repo holds
only the deployment glue: `docker-compose.yml`, the `Caddyfile`, and env config.

```
┌────────────── VM ──────────────┐
│  Caddy :80/:443  (auto-HTTPS)   │
│    ├── /api/*  → pocketbase:8090 │
│    ├── /_/*    → pocketbase:8090 │   (admin UI)
│    └── /*      → web:3000        │   (Next.js)
└─────────────────────────────────┘
```

## First-time deploy

On a fresh VM with Docker + Docker Compose installed and DNS for your domain
pointed at the VM's IP:

```bash
# 1. Clone with the app submodule
git clone --recurse-submodules <this-repo-url> portfolio-deploy
cd portfolio-deploy

# 2. Configure
cp .env.example .env
nano .env            # set DOMAIN, SITE_ORIGIN, ACME_EMAIL

# 3. Launch (Caddy fetches TLS certs automatically)
docker compose up -d --build
```

Then open `https://<your-domain>/_/` and create the PocketBase **superuser** admin
account. Schema and starter content are seeded automatically by the migrations
baked into the PocketBase image.

## Updating

After pushing changes to the `portfolio` app repo, ship them with:

```bash
./scripts/update.sh
```

This pulls the latest submodule commit, rebuilds the images, and restarts the
stack with near-zero downtime.

> To move the app submodule to a new commit deliberately:
> ```bash
> cd portfolio && git pull origin main && cd ..
> git add portfolio && git commit -m "Bump portfolio to latest"
> ```

## Configuration

| Variable      | Description                                                  |
| ------------- | ------------------------------------------------------------ |
| `DOMAIN`      | Hostname Caddy serves and obtains a certificate for          |
| `SITE_ORIGIN` | Public origin baked into the frontend (e.g. `https://d4m13n.dev`) |
| `ACME_EMAIL`  | Email for Let's Encrypt registration                         |

## Local test (no real domain)

Set `DOMAIN=localhost` and `SITE_ORIGIN=http://localhost` in `.env`, then
`docker compose up --build`. Caddy will serve a local self-signed cert; the
app is reachable at `https://localhost` (accept the warning) or you can hit the
services directly via the single-host compose file in the `portfolio` repo.

## Backups

All persistent state is the PocketBase SQLite database + uploads, stored in the
`pb_data` Docker volume:

```bash
docker run --rm -v portfolio-deploy_pb_data:/data -v "$PWD":/backup alpine \
  tar czf /backup/pb_data-backup.tgz -C /data .
```
