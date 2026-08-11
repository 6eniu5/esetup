#!/usr/bin/env bash
# Run a read-only query against the client's prod MSSQL through the home tunnel.
# Ensures the forward is up, then runs sqlcmd against the local forwarded port.
# Usage: db-query.sh "SELECT TOP 10 * FROM ..."   (or pipe SQL on stdin)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/db-tunnel.env"

[[ -f "$ENV_FILE" ]] || { echo "missing $ENV_FILE (copy db-tunnel.env.example and fill it in)" >&2; exit 1; }
# shellcheck disable=SC1090
set -a; source "$ENV_FILE"; set +a

: "${DB_USER:?set DB_USER in db-tunnel.env}"
: "${DB_PASSWORD:?set DB_PASSWORD in db-tunnel.env}"
LOCAL_PORT="${LOCAL_PORT:-14330}"

command -v sqlcmd >/dev/null || { echo "sqlcmd not installed (run the db-tunnel module)" >&2; exit 1; }

# Make sure the forward is live before querying.
"${SCRIPT_DIR}/db-tunnel.sh" up >/dev/null

# Pass the password via env, never on argv (it would show in `ps`). -C trusts the
# server cert (tunneling breaks the cert name match); -b makes sqlcmd exit nonzero on
# SQL errors so callers can detect failure.
export SQLCMDPASSWORD="$DB_PASSWORD"

if [[ -n "${1:-}" ]]; then
  exec sqlcmd -S "tcp:127.0.0.1,${LOCAL_PORT}" ${DB_NAME:+-d "$DB_NAME"} -U "$DB_USER" -C -b -Q "$1"
fi
# No inline query: read SQL from stdin.
exec sqlcmd -S "tcp:127.0.0.1,${LOCAL_PORT}" ${DB_NAME:+-d "$DB_NAME"} -U "$DB_USER" -C -b
