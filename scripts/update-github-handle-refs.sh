#!/usr/bin/env bash
# Rewrite GitHub *handle references in file contents* after a username change.
#
# Companion to update-github-remotes.sh (which fixes git remotes). This fixes
# the handle written into docs, .gitmodules, and setup scripts — in two forms:
#   1. URL form:  github.com/OLD  and  github.com:OLD      (clone/submodule URLs)
#   2. Slug form: OLD/repo         e.g. `OLD/dotfiles`, gh repo view OLD/x
#
# CRITICAL — it never rewrites the old handle when it is a filesystem PATH.
# On this machine OLD is also the name of a real directory (~/OLD/dotfiles), so
# any "OLD/" preceded by "/" or "~" (…/OLD/…, ~/OLD/…) is left untouched — only
# the folder rename can safely change those. Likewise it ignores non-slug bare
# uses (git identity name/email, the ssh key filename OLD_id_ed25519, the
# Bonjour hostname OLDs-macbook, the `gh` account) — those aren't "OLD/repo" and
# are separate, deliberate changes. Use --scan to audit everything it leaves.
#
# What it does:
#   1. Finds files with a github.com URL or a bare OLD/repo slug (not a path)
#   2. Skips history/app-state/build noise (.git, .claude, .cursor, node_modules,
#      target/dist/build, Library, shell histories, transcripts, backups)
#   3. --apply backs up each file, then rewrites URL + slug handles to NEW_HANDLE
#   4. --scan lists every remaining bare OLD_HANDLE so you can eyeball the
#      path/identity cases this script intentionally leaves alone
#   5. Writes a timestamped report (and backups) to ~/.github-remote-updates/
#
# Usage:
#   ./update-github-handle-refs.sh            # dry run: show refs that would change
#   ./update-github-handle-refs.sh --apply    # rewrite them (backs up first)
#   ./update-github-handle-refs.sh --scan     # list ALL bare OLD_HANDLE occurrences
#
# Override handles / root (defaults are this repo's own migration):
#   OLD_HANDLE=oldname NEW_HANDLE=newname ROOT=~/code ./update-github-handle-refs.sh
#
# Safe to re-run: rewriting is idempotent, and dry run / scan change nothing.

set -euo pipefail

OLD_HANDLE="${OLD_HANDLE:-6eniu5}"
NEW_HANDLE="${NEW_HANDLE:-kernvex}"
ROOT="${ROOT:-$HOME}"

MODE="dryrun"
case "${1:-}" in
  --apply) MODE="apply" ;;
  --scan)  MODE="scan" ;;
  ""|--dry-run|--dryrun) MODE="dryrun" ;;
  -h|--help) awk 'NR>1 && /^#/ {sub(/^# ?/,""); print; next} NR>1 {exit}' "$0"; exit 0 ;;
  *) echo "Unknown option: $1 (try --help)" >&2; exit 2 ;;
esac

if ! command -v rg >/dev/null 2>&1; then
  echo "ripgrep (rg) is required." >&2; exit 1
fi

# ---------- logging + backups ---------------------------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="${HOME}/.github-remote-updates"
BACKUP_DIR="${OUT_DIR}/backups-${STAMP}"
mkdir -p "$OUT_DIR"
REPORT="${OUT_DIR}/refs-report-${STAMP}-${MODE}.log"

log() { printf '%s\n' "$*" | tee -a "$REPORT"; }

# Directories / files that are history, app state, or generated — never rewrite.
EXCLUDES=(
  -g '!**/.git/**' -g '!**/node_modules/**' -g '!**/.Trash/**'
  -g '!**/.claude/**' -g '!**/.cursor/**' -g '!**/.gk/**'
  -g '!**/Library/**' -g '!**/target/**' -g '!**/dist/**' -g '!**/build/**'
  -g '!**/*.bak*' -g '!**/*history*' -g '!**/*.log' -g '!**/*.jsonl'
  -g '!**/.github-remote-updates/**'  # this tool's own reports + backups
  -g '!**/.claude.json*'  # Claude Code app state (a top-level FILE, not under .claude/)
)

# Match the handle in two safe forms (needs PCRE2 via rg -P for the lookarounds):
#   - github.com URL owner segment:  github.com[:/]OLD\b
#   - bare repo slug OLD/repo that is NOT a path: (?<![/~\w])OLD/[A-Za-z]
#     the lookbehind rejects ~/OLD and /OLD (filesystem paths) and word-joined
#     tokens; the lookahead requires a "/repo" so identity/hostname/key uses
#     (OLD@…, OLDs-…, OLD_id_…) never match.
MATCH_PATTERN="(github\.com[:/]${OLD_HANDLE}\b)|((?<![/~\w])${OLD_HANDLE}/[A-Za-z])"

# The equivalent rewrite, applied to each line (perl supports the same lookarounds).
PERL_SUBST='BEGIN{$o=quotemeta $ENV{OLD}; $n=$ENV{NEW}}
  s{(github\.com[:/])$o\b}{$1$n}g;
  s{(?<![/~\w])$o(?=/[A-Za-z])}{$n}g;'

log "== GitHub handle reference report =="
log "date:   $(date '+%Y-%m-%d %H:%M:%S')"
log "mode:   ${MODE}"
log "root:   ${ROOT}"
log "rename: ${OLD_HANDLE} -> ${NEW_HANDLE} (URL + repo-slug refs; paths/identity preserved)"
log "----------------------------------------"

# ---------- scan mode: report every bare occurrence, change nothing --------
if [[ "$MODE" == "scan" ]]; then
  log "All remaining '${OLD_HANDLE}' occurrences (context). --apply rewrites only"
  log "github.com URLs and bare OLD/repo slugs; paths/identity below stay put:"
  log ""
  rg -n --no-heading --hidden --no-ignore "${EXCLUDES[@]}" -e "$OLD_HANDLE" "$ROOT" 2>/dev/null \
    | tee -a "$REPORT" || true
  echo
  echo "Report saved to: ${REPORT}"
  exit 0
fi

# ---------- dryrun / apply -------------------------------------------------
# bash 3.2 (macOS default) has no mapfile — read the file list portably.
FILES=()
while IFS= read -r _f; do
  [[ -n "$_f" ]] && FILES+=("$_f")
done < <(rg -lP --hidden --no-ignore "${EXCLUDES[@]}" -e "$MATCH_PATTERN" "$ROOT" 2>/dev/null | sort)

files_changed=0
matches_total=0

for f in ${FILES[@]+"${FILES[@]}"}; do
  [[ -z "$f" ]] && continue
  count="$(rg -cP --no-ignore -e "$MATCH_PATTERN" "$f" 2>/dev/null || echo 0)"
  matches_total=$((matches_total + count))
  log "file:   $f  (${count} line(s) with matches)"
  # Show each matching line as old -> new so the change is reviewable.
  while IFS= read -r line; do
    newline="$(printf '%s' "$line" | OLD="$OLD_HANDLE" NEW="$NEW_HANDLE" perl -pe "$PERL_SUBST")"
    log "  - $line"
    log "  + $newline"
  done < <(rg -nP --no-heading --no-ignore -e "$MATCH_PATTERN" "$f" 2>/dev/null)

  if [[ "$MODE" == "apply" ]]; then
    rel="${f#"$ROOT"/}"
    dest="${BACKUP_DIR}/${rel}"
    mkdir -p "$(dirname "$dest")"
    cp -p "$f" "$dest"
    OLD="$OLD_HANDLE" NEW="$NEW_HANDLE" perl -pi -e "$PERL_SUBST" "$f"
    log "  status: UPDATED (backup: $dest)"
    files_changed=$((files_changed + 1))
  fi
  log ""
done

log "----------------------------------------"
if [[ "$MODE" == "apply" ]]; then
  log "Summary: rewrote handle refs across ${files_changed} file(s) (${matches_total} matching line(s))."
  log "Backups: ${BACKUP_DIR}"
else
  log "Summary: ${matches_total} matching line(s) across ${#FILES[@]} file(s) would change."
  log "Run with --apply to rewrite (backs up first), or --scan to audit bare occurrences."
fi
echo
echo "Report saved to: ${REPORT}"
