#!/usr/bin/env bash
# Generate the MechanicBuddy appsettings.Secrets.json from .env.
# Required because: (1) the MB API loads it with optional:false (must exist),
# and (2) the carcare DbUp migrator reads its DB connection from JSON only.
set -euo pipefail
cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "!! .env not found. Copy .env.example to .env first." >&2
  exit 1
fi

# Read a single key from .env without executing it (values may contain spaces,
# so we must NOT `source` the file). Strips optional surrounding quotes.
getval() {
  local key="$1" default="${2:-}" line
  line="$(grep -E "^${key}=" .env | tail -1 || true)"
  if [ -z "$line" ]; then
    printf '%s' "$default"
    return
  fi
  line="${line#*=}"
  line="${line%\"}"; line="${line#\"}"
  line="${line%\'}"; line="${line#\'}"
  printf '%s' "$line"
}

mkdir -p apps/mechanicbuddy/secrets
out=apps/mechanicbuddy/secrets/appsettings.Secrets.json

cat > "$out" <<JSON
{
  "DbOptions": {
    "Host": "pg",
    "Port": 5432,
    "UserId": "$(getval CARCARE_DB_USER carcare)",
    "Password": "$(getval CARCARE_DB_PASSWORD carcare)",
    "Name": "$(getval CARCARE_DB_NAME carcare)",
    "MultiTenancy": { "Enabled": false }
  },
  "JwtOptions": {
    "Secret": "$(getval MB_JWT_SECRET)",
    "ConsumerSecret": "$(getval MB_CONSUMER_SECRET)"
  },
  "SmtpOptions": {
    "Host": "mb-mailhog",
    "Port": "1025",
    "User": "",
    "Password": ""
  }
}
JSON

echo "==> Wrote $out"
