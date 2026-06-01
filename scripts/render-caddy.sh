#!/usr/bin/env bash
# Copy the Caddy site snippet for each ACTIVE profile into caddy/sites/, so the
# proxy only serves (and only requests certs for) apps that are actually running.
set -euo pipefail
cd "$(dirname "$0")/.."

profiles="${COMPOSE_PROFILES:-}"
# Fall back to the value in .env if not already in the environment.
if [ -z "$profiles" ] && [ -f .env ]; then
  profiles="$(grep -E '^COMPOSE_PROFILES=' .env | tail -1 | cut -d= -f2- | tr -d '"' | tr -d "'")"
fi

mkdir -p caddy/sites
rm -f caddy/sites/*.caddy

IFS=',' read -ra arr <<< "$profiles"
for p in "${arr[@]}"; do
  p="$(echo "$p" | xargs)"   # trim whitespace
  [ -z "$p" ] && continue
  tpl="caddy/site-templates/${p}.caddy"
  if [ -f "$tpl" ]; then
    cp "$tpl" "caddy/sites/${p}.caddy"
    echo "==> Caddy site enabled: ${p}"
  fi
done
