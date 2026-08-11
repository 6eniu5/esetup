#!/usr/bin/env bash
# Readiness check for the client DB tunnel: reports what's ready vs still pending,
# without printing any secret. Run any time: scripts/db-doctor.sh
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/db-tunnel.env"

ok()   { printf '  \033[0;32m✓\033[0m %s\n' "$1"; }
pend() { printf '  \033[0;33m…\033[0m %s\n' "$1"; }
bad()  { printf '  \033[0;31m✗\033[0m %s\n' "$1"; }

# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

echo "db-tunnel readiness"

# 1. Tooling
command -v sqlcmd >/dev/null && ok "sqlcmd installed" || bad "sqlcmd missing (run the db-tunnel module)"
if command -v tailscale >/dev/null; then TS=tailscale
elif [[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
else TS=""; fi
[[ -n "$TS" ]] && ok "Tailscale present" || bad "Tailscale not installed"

# 2. Config file
[[ -f "$ENV_FILE" ]] && ok "db-tunnel.env exists" || bad "db-tunnel.env missing (copy db-tunnel.env.example)"
for v in HOME_PIVOT HOME_USER HOME_SSH_KEY PROD_HOST DB_NAME DB_USER DB_PASSWORD; do
  # Never print the value — only whether it's set.
  if [[ -n "${!v:-}" ]]; then ok "$v set"; else pend "$v not set yet"; fi
done

# 3. Local SSH key
key="${HOME_SSH_KEY/#\~/$HOME}"
[[ -n "${HOME_SSH_KEY:-}" && -f "$key" ]] && ok "ssh key present ($HOME_SSH_KEY)" || pend "ssh key not found locally"

# 4. Reachability + auth to the home pivot
if [[ -n "${HOME_PIVOT:-}" ]] && nc -z -G 4 "$HOME_PIVOT" 22 >/dev/null 2>&1; then
  ok "home Mac reachable on :22 ($HOME_PIVOT)"
  if [[ -n "${HOME_USER:-}" && -f "$key" ]]; then
    if ssh -o BatchMode=yes -o ConnectTimeout=6 -i "$key" -o IdentitiesOnly=yes \
         "${HOME_USER}@${HOME_PIVOT}" true 2>/dev/null; then
      ok "passwordless SSH works"
    else
      pend "SSH key not yet authorized on the home Mac"
    fi
  fi
else
  pend "home Mac not reachable (Tailscale down on one end?)"
fi

# 5. Exit node (GUI mode)
if [[ -n "$TS" ]]; then
  if "$TS" exit-node list 2>/dev/null | grep -q "${EXIT_NODE:-__none__}"; then
    ok "exit node advertised & approved (${EXIT_NODE})"
  else
    pend "exit node not available yet (advertise on home + approve in admin console)"
  fi
fi

# 6. Tunnel state
"${SCRIPT_DIR}/db-tunnel.sh" status 2>/dev/null | sed 's/^/  /'
