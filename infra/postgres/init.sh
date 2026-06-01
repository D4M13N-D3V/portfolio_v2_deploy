#!/usr/bin/env bash
# Idempotent creation of per-app databases + owner roles on the shared Postgres.
# Runs on every `docker compose up` (not just first boot), so enabling a new app
# later still gets its database created. Each app runs its own schema migrations.
set -euo pipefail

create_role_and_db() {
  local db="$1" user="$2" pass="$3"
  [ -z "${db}" ] && return 0

  # Create or update the login role.
  psql -v ON_ERROR_STOP=1 --dbname postgres <<SQL
DO \$do\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = '${user}') THEN
    CREATE ROLE "${user}" LOGIN PASSWORD '${pass}';
  ELSE
    ALTER ROLE "${user}" WITH LOGIN PASSWORD '${pass}';
  END IF;
END
\$do\$;
SQL

  # Create the database if it doesn't exist (Postgres has no CREATE DATABASE IF NOT EXISTS).
  psql -v ON_ERROR_STOP=1 --dbname postgres <<SQL
SELECT 'CREATE DATABASE "${db}" OWNER "${user}"'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db}')\gexec
SQL

  psql -v ON_ERROR_STOP=1 --dbname postgres \
    -c "GRANT ALL PRIVILEGES ON DATABASE \"${db}\" TO \"${user}\";"

  echo "==> ready: database '${db}' owned by '${user}'"
}

echo "==> Initializing shared Postgres databases on ${PGHOST}"
create_role_and_db "${CARCARE_DB}"     "${CARCARE_USER}"     "${CARCARE_PASSWORD}"
create_role_and_db "${MB_MGMT_DB}"     "${MB_MGMT_USER}"     "${MB_MGMT_PASSWORD}"
create_role_and_db "${COMMISSIONS_DB}" "${COMMISSIONS_USER}" "${COMMISSIONS_PASSWORD}"
echo "==> Database initialization complete."
