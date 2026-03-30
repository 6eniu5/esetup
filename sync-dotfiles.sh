#!/usr/bin/env bash
# After `git pull` in esetup: rsync esetup/dotfiles -> TARGET_DOTFILES, then stow into $HOME.
# Matches sync_dotfiles_to_home + run_stow_all in setup.sh (non-interactive).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DOTFILES="${SCRIPT_DIR}/dotfiles"
TARGET_DOTFILES="${TARGET_DOTFILES:-${HOME}/6eniu5/dotfiles}"

log_info() { echo -e "\033[0;32m[INFO]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERR]\033[0m $*" >&2; }

# Stow a single package, automatically resolving conflicts:
#   - stale symlinks (pointing elsewhere) are removed
#   - real files/dirs are backed up to <path>.bak.<timestamp>
stow_pkg() {
  local pkg="$1"
  local output
  if output=$(cd "${TARGET_DOTFILES}" && stow --target="${HOME}" "$pkg" 2>&1); then
    log_info "Stowed package: $pkg"
    return 0
  fi

  local conflicts
  conflicts=$(echo "$output" | grep 'existing target is not owned by stow:' \
    | sed 's/.*existing target is not owned by stow: //' | xargs)

  if [[ -z "$conflicts" ]]; then
    log_error "Stow failed for $pkg: $output"
    return 1
  fi

  for rel_path in $conflicts; do
    local full="${HOME}/${rel_path}"
    if [[ -L "$full" ]]; then
      log_warn "Removing stale symlink: $full -> $(readlink "$full")"
      rm "$full"
    elif [[ -e "$full" ]]; then
      local bak="${full}.bak.$(date +%s)"
      log_warn "Backing up existing path: $full -> $bak"
      mv "$full" "$bak"
    fi
  done

  (cd "${TARGET_DOTFILES}" && stow --target="${HOME}" "$pkg")
  log_info "Stowed package: $pkg (resolved conflicts)"
}

usage() {
  echo "Usage: $0 [--sync-only]"
  echo "  Sync ${SOURCE_DOTFILES} -> \${TARGET_DOTFILES} (default: ~/6eniu5/dotfiles), then stow."
  echo "  --sync-only  Rsync only; skip stow (e.g. if you only need files on disk)."
  echo "Env: TARGET_DOTFILES"
}

SYNC_ONLY=0
for arg in "$@"; do
  case "$arg" in
    -h|--help) usage; exit 0 ;;
    --sync-only) SYNC_ONLY=1 ;;
    *) log_error "Unknown option: $arg"; usage; exit 1 ;;
  esac
done

log_info "Syncing ${SOURCE_DOTFILES} -> ${TARGET_DOTFILES}"
mkdir -p "${TARGET_DOTFILES}"
rsync -a \
  --exclude '.git' \
  --exclude 'nvim' \
  --exclude 'tmux-sessionizer' \
  "${SOURCE_DOTFILES}/" "${TARGET_DOTFILES}/"

mkdir -p "${TARGET_DOTFILES}/nvim/.config"
mkdir -p "${TARGET_DOTFILES}/bin/.local/bin"
chmod +x "${TARGET_DOTFILES}/bin/.local/bin/tmux-cht.sh" 2>/dev/null || true

if [[ -f "${TARGET_DOTFILES}/tmux-sessionizer/tmux-sessionizer" ]]; then
  ln -sf ../../../tmux-sessionizer/tmux-sessionizer "${TARGET_DOTFILES}/bin/.local/bin/tmux-sessionizer"
fi

if [[ "$SYNC_ONLY" -eq 1 ]]; then
  log_info "Done (sync only)."
  exit 0
fi

if ! command -v stow &>/dev/null; then
  log_error "stow not found; install it (e.g. brew install stow) or use --sync-only."
  exit 1
fi

mkdir -p "${HOME}/.config"
pkgs=(fish starship wezterm tmux tmux-sessionizer-config bin nvim)
for p in "${pkgs[@]}"; do
  if [[ -d "${TARGET_DOTFILES}/${p}" ]]; then
    stow_pkg "$p"
  else
    log_warn "Stow package dir missing: ${TARGET_DOTFILES}/${p}"
  fi
done

if [[ -f "${SCRIPT_DIR}/raycast/baseline.rayconfig" ]]; then
  log_info "Raycast config available at ${SCRIPT_DIR}/raycast/baseline.rayconfig — open it to import into Raycast."
fi

log_info "Done. Dotfiles tree: ${TARGET_DOTFILES}"
