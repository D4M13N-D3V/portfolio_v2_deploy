#!/usr/bin/env bash
# Pull the latest deploy config + app submodule, refresh images, and (re)start
# the stack. Run this on the VM to ship a new version.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "==> Pulling deploy repo + submodules"
git pull --recurse-submodules || true
git submodule update --init --remote --recursive || true

echo "==> Generating MechanicBuddy secrets file from .env"
./scripts/setup-secrets.sh

echo "==> Selecting active Caddy sites from COMPOSE_PROFILES"
./scripts/render-caddy.sh

echo "==> Pulling pre-built app images"
docker compose pull --ignore-buildable || docker compose pull || true

echo "==> Building source-based services (portfolio)"
docker compose build --pull

echo "==> Starting stack (one-shot migrators run automatically)"
docker compose up -d --remove-orphans

echo "==> Pruning dangling images"
docker image prune -f

echo "==> Current services:"
docker compose ps
