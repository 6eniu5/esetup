#!/usr/bin/env bash
# Rewrite git remotes across ~ after a GitHub handle (username) change.
#
# When you rename your GitHub account, existing remotes keep pointing at the
# old handle. GitHub redirects them for a while, then stops without warning
# (pushes start failing). This sweeps every repo under ~ and repoints only the
# remotes that still reference the old handle — repos with multiple remotes
# keep their other remotes untouched. Handles both SSH (git@github.com:old/…)
# and HTTPS (https://github.com/old/…) URLs.
#
# What it does:
#   1. Finds every git repo under ~ (default 5 levels deep)
#   2. Walks each remote by name and matches OLD_HANDLE in the URL
#   3. --apply rewrites matches to NEW_HANDLE; default is a preview (dry run)
#   4. --verify runs `git ls-remote` against each NEW_HANDLE remote to confirm
#      it authenticates (catches typos / access issues after the rename)
#   5. Writes a timestamped report to ~/.github-remote-updates/ every run
#
# Usage:
#   ./update-github-remotes.sh            # dry run: show what would change
#   ./update-github-remotes.sh --apply    # actually rewrite the remotes
#   ./update-github-remotes.sh --verify   # health-check the NEW_HANDLE remotes
#
# Override the handles (defaults are this repo's own migration):
#   OLD_HANDLE=oldname NEW_HANDLE=newname ./update-github-remotes.sh --apply
#
# Safe to re-run: rewriting is idempotent (a repo already on NEW_HANDLE no
# longer matches OLD_HANDLE), and dry run / verify never change anything.

set -euo pipefail

OLD_HANDLE="${OLD_HANDLE:-6eniu5}"
NEW_HANDLE="${NEW_HANDLE:-kernvex}"
ROOT="${ROOT:-$HOME}"
MAXDEPTH="${MAXDEPTH:-5}"

MODE="dryrun"
case "${1:-}" in
  --apply)  MODE="apply" ;;
  --verify) MODE="verify" ;;
  ""|--dry-run|--dryrun) MODE="dryrun" ;;
  -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

# ---------- logging --------------------------------------------------------
LOG_DIR="${HOME}/.github-remote-updates"
mkdir -p "$LOG_DIR"
REPORT="${LOG_DIR}/report-$(date +%Y%m%d-%H%M%S)-${MODE}.log"

# log() prints to the terminal AND appends to the report file.
log() { printf '%s\n' "$*" | tee -a "$REPORT"; }

log "== GitHub remote update report =="
log "date:   $(date '+%Y-%m-%d %H:%M:%S')"
log "mode:   ${MODE}"
log "root:   ${ROOT} (maxdepth ${MAXDEPTH})"
log "rename: ${OLD_HANDLE} -> ${NEW_HANDLE}"
log "----------------------------------------"

matched=0   # remotes still on OLD_HANDLE
changed=0   # remotes rewritten this run
verify_ok=0
verify_fail=0

# Never let git block on a credential prompt — fail fast so we log the error
# instead of hanging.
export GIT_TERMINAL_PROMPT=0
export GIT_SSH_COMMAND="ssh -o BatchMode=yes -o ConnectTimeout=10"

while IFS= read -r -d '' gitdir; do
  repo="$(dirname "$gitdir")"

  # Walk each remote by name so multi-remote repos are handled precisely.
  while IFS= read -r remote; do
    [[ -z "$remote" ]] && continue
    url="$(git -C "$repo" remote get-url "$remote")"

    case "$MODE" in
      dryrun|apply)
        if [[ "$url" == *"${OLD_HANDLE}"* ]]; then
          matched=$((matched + 1))
          newurl="${url//${OLD_HANDLE}/${NEW_HANDLE}}"
          log "repo:   $repo"
          log "  remote: $remote"
          log "  old:    $url"
          log "  new:    $newurl"
          if [[ "$MODE" == "apply" ]]; then
            if git -C "$repo" remote set-url "$remote" "$newurl"; then
              log "  status: UPDATED"
              changed=$((changed + 1))
            else
              log "  status: FAILED to set-url"
            fi
          else
            log "  status: would update"
          fi
          log ""
        fi
        ;;
      verify)
        if [[ "$url" == *"${NEW_HANDLE}"* ]]; then
          if git -C "$repo" ls-remote --exit-code "$remote" >/dev/null 2>&1; then
            log "OK    $repo ($remote -> $url)"
            verify_ok=$((verify_ok + 1))
          else
            log "FAIL  $repo ($remote -> $url)"
            verify_fail=$((verify_fail + 1))
          fi
        fi
        ;;
    esac
  done < <(git -C "$repo" remote)

done < <(find "$ROOT" -maxdepth "$MAXDEPTH" -type d -name .git -not -path '*/.Trash/*' -print0 2>/dev/null)

log "----------------------------------------"
case "$MODE" in
  dryrun) log "Summary: ${matched} remote(s) would be updated." ;;
  apply)  log "Summary: ${changed}/${matched} remote(s) updated." ;;
  verify) log "Summary: ${verify_ok} OK, ${verify_fail} FAIL." ;;
esac
echo
echo "Report saved to: ${REPORT}"
