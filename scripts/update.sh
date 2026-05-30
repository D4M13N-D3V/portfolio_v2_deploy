#!/usr/bin/env bash
# Pull the latest deploy config + app submodule and rebuild the stack.
# Run this on the VM to ship a new version.
set -euo pipefail

cd "$(dirname "$0")/.."

echo "==> Pulling deploy repo + submodules"
git pull --recurse-submodules
git submodule update --init --remote --recursive

echo "==> Rebuilding and restarting"
docker compose up -d --build

echo "==> Pruning dangling images"
docker image prune -f

echo "==> Done. Current services:"
docker compose ps
