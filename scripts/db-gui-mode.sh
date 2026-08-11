#!/usr/bin/env bash
# Route ALL of this laptop's traffic through the home Mac (Tailscale exit node), so the
# browser, GUI DB tools, and sites like whatismyip all show the home residential IP.
# This is the full-tunnel counterpart to db-tunnel.sh (which forwards only the DB port).
# Toggle it on only while exploring; leave it off for normal work.
#
# One-time prerequisites (see modules/db-tunnel.sh manual notes):
#   1. Home Mac advertises the exit node (Tailscale app: This device -> Exit node ->
#      Run as exit node; or `tailscale set --advertise-exit-node`).
#   2. Approve it once in the admin console (Machines -> home Mac -> exit node route).
#
# Usage: db-gui-mode.sh [on|off|status]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/db-tunnel.env"
# shellcheck disable=SC1090
[[ -f "$ENV_FILE" ]] && { set -a; source "$ENV_FILE"; set +a; }

# Prefer a tailscale on PATH; fall back to the macOS app bundle's CLI.
if command -v tailscale >/dev/null 2>&1; then
  TS=tailscale
elif [[ -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then
  TS=/Applications/Tailscale.app/Contents/MacOS/Tailscale
else
  echo "tailscale CLI not found (is the app installed?)" >&2; exit 1
fi

show_ip() { curl -s --max-time 8 https://api.ipify.org && echo || echo "(could not reach ipify)"; }

case "${1:-status}" in
  on)
    : "${EXIT_NODE:?set EXIT_NODE in db-tunnel.env (the home Mac Tailscale name)}"
    # allow-lan-access keeps local devices (printers, router) reachable while tunneled.
    "$TS" set --exit-node="$EXIT_NODE" --exit-node-allow-lan-access=true
    echo "exit node ON -> $EXIT_NODE"
    echo -n "public IP now: "; show_ip
    ;;
  off)
    "$TS" set --exit-node=
    echo "exit node OFF (direct connection)"
    echo -n "public IP now: "; show_ip
    ;;
  status)
    echo -n "current public IP: "; show_ip
    echo "(if this matches your home IP, home-egress is active)"
    ;;
  *)
    echo "usage: $(basename "$0") [on|off|status]" >&2; exit 2 ;;
esac
