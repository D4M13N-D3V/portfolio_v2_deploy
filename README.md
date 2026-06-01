# portfolio-deploy

Single-host **Docker Compose** platform that runs **d4m13n.dev** plus a set of
demo applications behind one Caddy reverse proxy with automatic HTTPS. **No
Kubernetes.**

Each app is a self-contained Compose file pulled into one project via Compose
`include:`. Which apps run is controlled by a single `COMPOSE_PROFILES` line in
`.env`. Adding another app later is a small, repeatable change.

```
┌──────────────────────────── VM ────────────────────────────┐
│  Caddy :80/:443  (auto-HTTPS, one site block per app)       │
│                                                              │
│  d4m13n.dev                          → web + pocketbase      │  portfolio
│  mechanicbuddy.demos.d4m13n.dev      → mb-web                │
│  api.mechanicbuddy.demos.d4m13n.dev  → mb-api                │  mechanicbuddy
│  manage[-api].mechanicbuddy.demos…   → management portal/api │
│  commissions.demos.d4m13n.dev        → commissions-ui        │
│  api.commissions.demos.d4m13n.dev    → commissions-core-api  │  commissions
│                                                              │
│  Shared Postgres 16  (carcare, mb_management, comissionsapp) │
└──────────────────────────────────────────────────────────────┘
```

## Layout

```
docker-compose.yml            # aggregator: include: of everything below
.env                          # the ONE place you configure all apps
scripts/
  update.sh                   # deploy / redeploy on the VM
  setup-secrets.sh            # writes MechanicBuddy's appsettings.Secrets.json from .env
  render-caddy.sh             # picks Caddy site files for the active profiles
infra/
  postgres/                   # shared Postgres + idempotent DB/role bootstrap
  caddy/                      # the always-on reverse proxy
apps/
  portfolio/                  # built from the ./portfolio submodule
  mechanicbuddy/              # pre-built ghcr.io images + mounted secrets
  commissions/                # pre-built ghcr.io images
caddy/
  Caddyfile                   # imports the active site snippets
  site-templates/<app>.caddy  # one routing snippet per app
  sites/                      # generated at deploy time (gitignored)
```

## First-time deploy

On a fresh Linux VM with Docker + Docker Compose installed, and DNS pointed at
the VM's IP:

- `d4m13n.dev` → VM IP
- `*.demos.d4m13n.dev` (wildcard) → VM IP — covers every demo subdomain

```bash
# 1. Clone with the portfolio submodule
git clone --recurse-submodules <this-repo-url> portfolio-deploy
cd portfolio-deploy

# 2. Configure
cp .env.example .env
nano .env          # set passwords, secrets, Auth0, and (optionally) trim COMPOSE_PROFILES

# 3. Deploy (generates secrets + Caddy sites, pulls images, builds portfolio, starts everything)
./scripts/update.sh
```

Then open `https://d4m13n.dev/_/` and create the PocketBase **superuser**.

## Configuration

Everything lives in `.env`. Key groups:

| Group | Purpose |
| --- | --- |
| `COMPOSE_PROFILES` | Comma-separated list of apps to run: `portfolio`, `mechanicbuddy`, `commissions`. Remove one to stop running it. |
| Hostnames | One variable per public subdomain. Caddy serves exactly these. |
| `POSTGRES_*` / `*_DB_*` | Shared Postgres superuser + per-app database name/user/password. |
| `MB_*` | MechanicBuddy JWT/session secrets and optional Stripe/Resend keys. |
| `COMMISSIONS_AUTH0_*` | Auth0 config for the commissions demo (**required for login**). |
| `*_IMAGE` | Pinned image references — change a tag/path if an image moves. |

## Choosing which apps run

Set `COMPOSE_PROFILES` in `.env`, then run `./scripts/update.sh`. Caddy is
always on; the shared Postgres only starts when an app that needs it is enabled.
`render-caddy.sh` ensures only enabled apps get a Caddy site block (and a TLS
cert), so a disabled app never causes ACME churn.

## Updating

```bash
./scripts/update.sh
```

Pulls the latest deploy config + portfolio submodule, refreshes pre-built
images, rebuilds the portfolio, re-runs database migrators, and restarts.

## Adding a new app later

1. Create `apps/<name>/compose.yaml` (services tagged `profiles: [<name>]`,
   joined to the shared network by name, using `pg` if a database is needed).
2. Add `apps/<name>/compose.yaml` to `include:` in `docker-compose.yml`.
3. Add `caddy/site-templates/<name>.caddy` routing its subdomain(s).
4. Add hostnames/secrets to `.env(.example)`; if it needs a database, add it to
   `infra/postgres/init.sh` and the `pg`/`pg-init` profile lists.
5. Add `<name>` to `COMPOSE_PROFILES` and run `./scripts/update.sh`.

## Known limitations (current demo images)

These stem from how the upstream images are built, not from this repo. The
deployment runs; these specific surfaces need an image rebuild to be fully wired:

- **MechanicBuddy management API** tenant provisioning expects Helm/Kubernetes;
  paid-tenant provisioning won't work on a single Docker host. The rest runs.
- **Commissions UI** mostly works (auth + the server-side API proxy read
  `NEXT_PUBLIC_API_URL` at runtime, which is set here). However two components
  (`portfolioImage.tsx` / `editablePortfolioImage.tsx`) put `NEXT_PUBLIC_API_URL`
  directly into browser `<img src>` tags, which use the **build-time** value —
  and the published image didn't bake one, so artist-portfolio thumbnails
  resolve to `undefined/...` until the image is rebuilt with that build arg.

> Note: MechanicBuddy's `mb-web` and `management-portal` images also have a
> `localhost` API URL baked in, but it is **dead** — both frontends route every
> API call through server-side proxy routes using the runtime `API_URL` /
> `MANAGEMENT_API_URL` (set above), so they work as-is behind the proxy.
- **Commissions login** requires the Auth0 application to whitelist the deployed
  callback/logout/web-origin URLs (see `.env.example`).

## Backups

Persistent state lives in Docker volumes: `pb_data` (PocketBase) and `pg_data`
(all app databases). Example:

```bash
docker run --rm -v portfolio-deploy_pg_data:/data -v "$PWD":/backup alpine \
  tar czf /backup/pg_data-backup.tgz -C /data .
```

## Local test (no real domain)

Set the host variables to `localhost`-style names you've added to `/etc/hosts`,
or simply hit individual services after `docker compose up`. Caddy will serve a
self-signed cert for unknown hostnames (accept the warning).
