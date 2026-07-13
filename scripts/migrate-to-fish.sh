#!/usr/bin/env bash
# One-shot migration from zsh to fish as the default shell.
#
# What it does:
#   1. Verifies fish + key CLI tools are installed (offers to brew-install missing ones)
#   2. Adds fish to /etc/shells (sudo) and sets it as the login shell via chsh
#   3. Links Homebrew completions for fish
#   4. Syncs the latest dotfiles (config.fish now includes former .zshrc items)
#   5. Backs up ~/.zshrc so it stays around but won't load by default
#
# Safe to re-run: every step is idempotent.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log_info() { echo -e "\033[0;32m[INFO]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERR]\033[0m $*" >&2; }

prompt_yes_no() {
  local msg="$1" default="${2:-y}" hint="[Y/n]"
  [[ "$default" == "n" ]] && hint="[y/N]"
  read -r -p "${msg} ${hint} " ans || true
  ans="${ans:-$default}"
  [[ "$ans" =~ ^[Yy] ]]
}

# ---------- 1. Verify fish is installed ------------------------------------------
fish_path="$(command -v fish 2>/dev/null || true)"
if [[ -z "$fish_path" ]]; then
  if command -v brew &>/dev/null; then
    log_warn "fish not found on PATH."
    if prompt_yes_no "Install fish via Homebrew?" y; then
      brew install fish
      eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv)"
      fish_path="$(command -v fish)"
    else
      log_error "fish is required. Aborting."; exit 1
    fi
  else
    log_error "Neither fish nor Homebrew found. Run setup.sh first."; exit 1
  fi
fi
log_info "fish found at ${fish_path}"

# ---------- 2. Check key CLI tools are present -----------------------------------
missing=()
for tool in starship zoxide atuin eza bat fnm stow; do
  command -v "$tool" &>/dev/null || missing+=("$tool")
done

if [[ ${#missing[@]} -gt 0 ]]; then
  log_warn "Missing tools: ${missing[*]}"
  if prompt_yes_no "Install them via Homebrew?" y; then
    brew install "${missing[@]}"
  else
    log_warn "Continuing without installing: ${missing[*]}"
  fi
fi

# ---------- 3. Add fish to /etc/shells -------------------------------------------
if ! grep -qF "$fish_path" /etc/shells 2>/dev/null; then
  log_info "Adding ${fish_path} to /etc/shells (requires sudo)"
  if ! echo "$fish_path" | sudo tee -a /etc/shells >/dev/null 2>&1; then
    log_warn "Could not write to /etc/shells automatically."
    log_warn "Run manually:  echo ${fish_path} | sudo tee -a /etc/shells"
    NEED_MANUAL_SHELL=1
  fi
else
  log_info "${fish_path} already in /etc/shells"
fi

# ---------- 4. Set fish as default login shell -----------------------------------
if [[ "${SHELL:-}" != "$fish_path" ]]; then
  if [[ "${NEED_MANUAL_SHELL:-0}" -eq 1 ]]; then
    log_warn "Skipping chsh (fish not yet in /etc/shells). After running the sudo command above:"
    log_warn "  chsh -s ${fish_path}"
  else
    log_info "Changing default shell to fish"
    if chsh -s "$fish_path" 2>/dev/null; then
      log_info "Login shell set to ${fish_path} (takes effect on new terminal sessions)"
    else
      log_warn "chsh failed. Run manually:  chsh -s ${fish_path}"
    fi
  fi
else
  log_info "Default shell is already fish"
fi

# ---------- 5. Link Homebrew completions for fish --------------------------------
if command -v brew &>/dev/null; then
  if SHELL="$fish_path" brew completions link 2>/dev/null; then
    log_info "Linked Homebrew completions for fish"
  else
    log_warn "brew completions link reported an issue (may already be linked)"
  fi
fi

# ---------- 6. Sync dotfiles (updated config.fish with .zshrc items) -------------
log_info "Running sync-dotfiles.sh to apply updated fish config"
"${SCRIPT_DIR}/sync-dotfiles.sh"

# ---------- 7. Back up .zshrc ----------------------------------------------------
if [[ -f "${HOME}/.zshrc" ]]; then
  backup="${HOME}/.zshrc.bak.$(date +%s)"
  if prompt_yes_no "Back up ~/.zshrc to ${backup}? (It will remain on disk but won't load in fish)" y; then
    cp "${HOME}/.zshrc" "$backup"
    log_info "Backed up ~/.zshrc -> ${backup}"
  fi
fi

echo
log_info "Migration complete!"
log_info "Your fish config now includes: starship, zoxide, atuin, fnm --use-on-cd,"
log_info "  mise, JAVA_HOME, CU_OWNER, AWS_PROFILE, PNPM_HOME, gwta, get_dd_key."
log_info "Open a new terminal — or run: exec fish"
