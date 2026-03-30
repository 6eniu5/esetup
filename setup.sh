#!/usr/bin/env bash
# macOS bootstrap: Homebrew, CLI tools, runtimes, dotfiles (stow), submodules.
# 2-space indent; guard clauses; interactive prompts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DOTFILES="${SCRIPT_DIR}/dotfiles"
TARGET_DOTFILES="${TARGET_DOTFILES:-${HOME}/6eniu5/dotfiles}"
# Decrypted key from 6eniu5/ssh vault; per-repo git core.sshCommand uses this (no global ~/.ssh/config Host github.com).
ESETUP_SSH_IDENTITY="${ESETUP_SSH_IDENTITY:-${HOME}/.ssh/6eniu5_id_ed25519}"

# Set by preflight_environment; 1 = do not install OrbStack cask this run
SKIP_ORBSTACK=0
SKIP_PREFLIGHT=0
CAVEATS_INFO=()
CAVEATS_ACTION=()

log_info() { echo -e "\033[0;32m[INFO]\033[0m $*"; }
log_warn() { echo -e "\033[0;33m[WARN]\033[0m $*"; }
log_error() { echo -e "\033[0;31m[ERR]\033[0m $*" >&2; }

prompt_yes_no() {
  local msg="$1"
  local default="${2:-n}"
  local hint="[y/N]"
  [[ "$default" == "y" ]] && hint="[Y/n]"
  read -r -p "${msg} ${hint} " ans || true
  ans="${ans:-}"
  if [[ -z "$ans" ]]; then
    [[ "$default" == "y" ]] && return 0
    return 1
  fi
  [[ "$ans" =~ ^[Yy] ]]
}

array_contains() {
  local needle="$1"
  shift
  local item
  for item in "$@"; do
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

get_brew_caveat_json() {
  local kind="$1"
  local name="$2"
  if [[ "$kind" == "formula" ]]; then
    brew info --json=v2 --formula "$name" 2>/dev/null || true
    return 0
  fi
  brew info --json=v2 --cask "$name" 2>/dev/null || true
}

record_caveat() {
  local kind="$1"
  local name="$2"

  if ! command -v jq &>/dev/null; then
    log_warn "jq not found; skipping caveat capture for ${name}."
    return 0
  fi

  local raw_json
  raw_json="$(get_brew_caveat_json "$kind" "$name")"
  [[ -n "$raw_json" ]] || return 0

  local caveat
  if [[ "$kind" == "formula" ]]; then
    caveat="$(printf '%s' "$raw_json" | jq -r '.formulae[0].caveats // empty' 2>/dev/null || true)"
  else
    caveat="$(printf '%s' "$raw_json" | jq -r '.casks[0].caveats // empty' 2>/dev/null || true)"
  fi
  [[ -n "$caveat" ]] || return 0
  [[ "$caveat" == "null" ]] && return 0

  local entry
  entry="${name}: ${caveat}"

  local lc
  lc="$(printf '%s' "$caveat" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lc" == *"path"* ]] \
    || [[ "$lc" == *"shellenv"* ]] \
    || [[ "$lc" == *"service"* ]] \
    || [[ "$lc" == *"launchctl"* ]] \
    || [[ "$lc" == *"manual"* ]] \
    || [[ "$lc" == *"completions"* ]] \
    || [[ "$lc" == *"post-install"* ]] \
    || [[ "$lc" == *"post install"* ]]; then
    if ! array_contains "$entry" "${CAVEATS_ACTION[@]+"${CAVEATS_ACTION[@]}"}"; then
      CAVEATS_ACTION+=("$entry")
    fi
    return 0
  fi

  if ! array_contains "$entry" "${CAVEATS_INFO[@]+"${CAVEATS_INFO[@]}"}"; then
    CAVEATS_INFO+=("$entry")
  fi
}

print_caveat_summary() {
  local has_any=0
  if [[ "${#CAVEATS_ACTION[@]}" -gt 0 ]]; then
    has_any=1
    echo
    echo "=============================="
    echo "Action required caveats"
    echo "=============================="
    local item
    for item in "${CAVEATS_ACTION[@]+"${CAVEATS_ACTION[@]}"}"; do
      echo
      printf '%s\n' "$item"
    done
  fi

  if [[ "${#CAVEATS_INFO[@]}" -gt 0 ]]; then
    has_any=1
    echo
    echo "=============================="
    echo "Informational caveats"
    echo "=============================="
    local info_item
    for info_item in "${CAVEATS_INFO[@]+"${CAVEATS_INFO[@]}"}"; do
      echo
      printf '%s\n' "$info_item"
    done
  fi

  [[ "$has_any" -eq 1 ]] || log_info "No Homebrew caveats collected."
}

ensure_line_in_file() {
  local line="$1"
  local file="$2"
  [[ -f "$file" ]] || touch "$file"
  grep -Fqx "$line" "$file" && return 0
  printf '%s\n' "$line" >> "$file"
}

# Homebrew infers the target shell from $SHELL for completion install paths and caveat text.
# Call after fish is on PATH so subsequent brew installs target fish instead of zsh.
export_shell_for_homebrew_fish() {
  if command -v fish &>/dev/null; then
    SHELL="$(command -v fish)"
    export SHELL
    log_info "Using SHELL=${SHELL} for Homebrew (fish-targeted completions and caveats)."
  else
    log_warn "fish not on PATH; Homebrew will infer completion hints from your login shell."
  fi
}

link_homebrew_completions_for_fish() {
  command -v fish &>/dev/null || return 0
  local fish_bin
  fish_bin="$(command -v fish)"
  if SHELL="$fish_bin" brew completions link 2>/dev/null; then
    log_info "Ran: brew completions link (fish)."
  fi
}

apply_known_caveat_actions() {
  local fish_cfg="${TARGET_DOTFILES}/fish/.config/fish/config.fish"
  local need_fish_paths=0
  local item
  for item in "${CAVEATS_ACTION[@]+"${CAVEATS_ACTION[@]}"}"; do
    local lc_item
    lc_item="$(printf '%s' "$item" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lc_item" == *"fish completions"* ]] || [[ "$lc_item" == *"vendor_completions.d"* ]]; then
      need_fish_paths=1
      break
    fi
  done

  if [[ "$need_fish_paths" -eq 1 ]]; then
    mkdir -p "$(dirname "$fish_cfg")"
    ensure_line_in_file "" "$fish_cfg"
    ensure_line_in_file "# Homebrew fish completion paths (auto-added from caveat actions)" "$fish_cfg"
    ensure_line_in_file "if test -d (brew --prefix)/share/fish/completions" "$fish_cfg"
    ensure_line_in_file "  set -p fish_complete_path (brew --prefix)/share/fish/completions" "$fish_cfg"
    ensure_line_in_file "end" "$fish_cfg"
    ensure_line_in_file "if test -d (brew --prefix)/share/fish/vendor_completions.d" "$fish_cfg"
    ensure_line_in_file "  set -p fish_complete_path (brew --prefix)/share/fish/vendor_completions.d" "$fish_cfg"
    ensure_line_in_file "end" "$fish_cfg"
    log_info "Applied known caveat action: added Homebrew fish completion paths to ${fish_cfg}."
  fi

  if [[ "${#CAVEATS_ACTION[@]}" -gt 0 ]]; then
    log_info "Manual caveat actions may still be needed for service/launchctl/path caveats shown above."
  fi
}

brew_install_formula() {
  local formula="$1"
  local desc="${2:-$formula}"
  if brew list --formula "$formula" &>/dev/null; then
    case "${BREW_IF_INSTALLED:-prompt}" in
      skip)
        log_info "Skipping already-installed formula: $formula"
        return 0
        ;;
      upgrade)
        log_info "Upgrading formula: $formula"
        brew upgrade "$formula" || log_warn "brew upgrade failed for ${formula}"
        record_caveat formula "$formula"
        return 0
        ;;
      prompt|*)
        if ! prompt_yes_no "${desc} already present. Reinstall or proceed with setup step anyway?" n; then
          log_warn "Skipping formula: $formula"
          return 0
        fi
        ;;
    esac
  fi
  brew install "$formula"
  record_caveat formula "$formula"
}

brew_install_cask() {
  local cask="$1"
  local desc="${2:-$cask}"
  if brew list --cask "$cask" &>/dev/null; then
    case "${BREW_IF_INSTALLED:-prompt}" in
      skip)
        log_info "Skipping already-installed cask: $cask"
        return 0
        ;;
      upgrade)
        log_info "Upgrading cask: $cask"
        brew upgrade --cask "$cask" || log_warn "brew upgrade --cask failed for ${cask}"
        record_caveat cask "$cask"
        return 0
        ;;
      prompt|*)
        if ! prompt_yes_no "${desc} already present. Reinstall or proceed with setup step anyway?" n; then
          log_warn "Skipping cask: $cask"
          return 0
        fi
        ;;
    esac
  fi

  local output=""
  if output="$(brew install --cask "$cask" 2>&1)"; then
    [[ -n "$output" ]] && printf '%s\n' "$output"
    record_caveat cask "$cask"
    return 0
  fi

  printf '%s\n' "$output" >&2
  if [[ "$output" == *"already an App at '"* ]]; then
    local app_path
    app_path="$(printf '%s\n' "$output" | sed -n "s/.*already an App at '\\([^']*\\)'.*/\\1/p" | head -n 1)"
    if [[ -z "$app_path" ]]; then
      log_error "Cask install failed for ${cask}."
      return 1
    fi

    if prompt_yes_no "${app_path} already exists. Remove it and retry installing ${cask}?" n; then
      rm -rf "$app_path"
      brew install --cask "$cask"
      record_caveat cask "$cask"
      return 0
    fi

    if prompt_yes_no "Skip ${cask} and continue setup?" y; then
      log_warn "Skipped cask due to existing app: ${cask}"
      return 0
    fi
  fi

  log_error "Cask install failed for ${cask}."
  return 1
}

ensure_homebrew() {
  ARCH="$(uname -m)"
  if [[ "$ARCH" == "arm64" ]]; then
    BREW_PREFIX="/opt/homebrew"
  else
    BREW_PREFIX="/usr/local"
  fi
  export BREW_PREFIX

  if [[ -x "${BREW_PREFIX}/bin/brew" ]]; then
    eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
    return 0
  fi

  if ! prompt_yes_no "Homebrew not found at ${BREW_PREFIX}. Install Homebrew?" y; then
    log_error "Homebrew is required."
    exit 1
  fi
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  eval "$("${BREW_PREFIX}/bin/brew" shellenv)"
}

app_in_applications() {
  local name="$1"
  [[ -d "/Applications/${name}.app" ]]
}

brew_cask_installed() {
  command -v brew &>/dev/null && brew list --cask "$1" &>/dev/null
}

docker_desktop_present() {
  app_in_applications "Docker" \
    || brew_cask_installed docker \
    || brew_cask_installed docker-desktop
}

orbstack_present() {
  app_in_applications "OrbStack" || brew_cask_installed orbstack
}

rancher_desktop_present() {
  app_in_applications "Rancher Desktop" \
    || brew_cask_installed rancher-desktop \
    || brew_cask_installed rancher
}

colima_present() {
  brew list --formula colima &>/dev/null || command -v colima &>/dev/null
}

preflight_environment() {
  log_info "Preflight: checking for common conflicts (Docker, OrbStack, dotfiles, Homebrew)"

  if [[ -x /opt/homebrew/bin/brew ]] && [[ -x /usr/local/bin/brew ]]; then
    log_warn "Two Homebrew installations detected (/opt/homebrew and /usr/local)."
    log_warn "This script uses BREW_PREFIX=${BREW_PREFIX} after shellenv."
    if ! prompt_yes_no "Continue using the active brew from shellenv (see: brew --prefix)?" y; then
      exit 1
    fi
  fi

  if [[ -d "${TARGET_DOTFILES}" ]]; then
    local count
    count="$(find "${TARGET_DOTFILES}" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "${count:-0}" -gt 0 ]] && [[ ! -d "${TARGET_DOTFILES}/.git" ]]; then
      log_warn "${TARGET_DOTFILES} exists with content but has no .git (not a dotfiles repo yet)."
      log_warn "Rsync will merge files from ${SOURCE_DOTFILES}; it will not delete extra files in the target."
      if ! prompt_yes_no "Proceed with sync into ${TARGET_DOTFILES}?" n; then
        exit 1
      fi
    fi
  fi

  if docker_desktop_present && orbstack_present; then
    log_warn "Both Docker Desktop and OrbStack appear to be installed."
    log_warn "Only one Docker stack should own the docker CLI / socket; conflicts are common."
    if ! prompt_yes_no "Continue setup anyway? (Consider removing or quitting one.)" n; then
      exit 1
    fi
  elif docker_desktop_present && ! orbstack_present; then
    log_warn "Docker Desktop is installed. OrbStack also provides Docker and typically should not run alongside it."
    echo "  1) Skip installing OrbStack this run (recommended if you keep Docker Desktop)"
    echo "  2) Install OrbStack anyway (quit Docker Desktop; plan to use one stack only)"
    echo "  3) Abort setup"
    read -r -p "Choose [1-3, default 1]: " orb_choice || true
    orb_choice="${orb_choice:-1}"
    case "$orb_choice" in
      1) SKIP_ORBSTACK=1 ;;
      2) SKIP_ORBSTACK=0 ;;
      3) log_info "Aborted."; exit 1 ;;
      *) SKIP_ORBSTACK=1 ;;
    esac
  fi

  if rancher_desktop_present; then
    log_warn "Rancher Desktop is installed (Kubernetes/Docker). It can overlap with Docker Desktop or OrbStack."
    if ! prompt_yes_no "Continue setup?" y; then
      exit 1
    fi
  fi

  if colima_present; then
    log_warn "Colima is present (container runtime). It can conflict with other Docker endpoints if multiple are active."
    if ! prompt_yes_no "Continue setup?" y; then
      exit 1
    fi
  fi

  if command -v docker &>/dev/null; then
    if docker info &>/dev/null; then
      log_info "docker CLI responds (docker info OK)."
    else
      log_warn "docker CLI exists but 'docker info' failed (daemon not running or context broken)."
      if ! prompt_yes_no "Continue setup anyway?" y; then
        exit 1
      fi
    fi
  fi
}

sync_dotfiles_to_home() {
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
}

init_dotfiles_git() {
  cd "${TARGET_DOTFILES}" || exit 1
  [[ -d .git ]] || git init

  if [[ -f "$ESETUP_SSH_IDENTITY" ]]; then
    # -F /dev/null bypasses ~/.ssh/config so its IdentityFile directives
    # don't shadow the 6eniu5 key.
    local ssh_cmd="ssh -F /dev/null -i \"$ESETUP_SSH_IDENTITY\" -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=\"$HOME/.ssh/known_hosts\""
    git config core.sshCommand "$ssh_cmd"
    log_info "Dotfiles repo will use ${ESETUP_SSH_IDENTITY} for git@github.com (per-repo only, ~/.ssh/config bypassed)."
  fi

  if [[ ! -d nvim/.config/nvim/.git ]]; then
    rm -rf nvim/.config/nvim
    git submodule add git@github.com:6eniu5/kickstart.nvim.git nvim/.config/nvim || log_warn "Submodule nvim add failed (SSH / network). Run: git submodule add git@github.com:6eniu5/kickstart.nvim.git nvim/.config/nvim"
  fi
  if [[ ! -d tmux-sessionizer/.git ]]; then
    rm -rf tmux-sessionizer
    git submodule add git@github.com:6eniu5/tmux-sessionizer.git tmux-sessionizer || log_warn "Submodule tmux-sessionizer add failed. Run: git submodule add git@github.com:6eniu5/tmux-sessionizer.git tmux-sessionizer"
  fi
  git submodule update --init --recursive || true
  if [[ -f "${TARGET_DOTFILES}/tmux-sessionizer/tmux-sessionizer" ]]; then
    ln -sf ../../../tmux-sessionizer/tmux-sessionizer "${TARGET_DOTFILES}/bin/.local/bin/tmux-sessionizer"
  fi
}

run_fnm_default_node() {
  command -v fnm &>/dev/null || return 0
  if prompt_yes_no "Install default Node LTS via fnm (fnm install --lts && fnm default lts-latest)?" y; then
    fnm install --lts
    fnm default lts-latest
  fi
}

optional_miniconda() {
  if ! prompt_yes_no "Install Miniconda (Python version management)?" n; then
    return 0
  fi
  if brew list --cask miniconda &>/dev/null; then
    if ! prompt_yes_no "Miniconda is already installed. Reinstall?" n; then
      return 0
    fi
  fi
  brew install --cask miniconda
}

optional_sdkman() {
  if ! prompt_yes_no "Install SDKMAN! (Java) and fish integrations (fisher + sdkman-for-fish)?" n; then
    return 0
  fi
  if [[ ! -d "${HOME}/.sdkman" ]]; then
    curl -s "https://get.sdkman.io" | bash
  fi
  # fisher + sdkman-for-fish (requires fish)
  fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher reitzig/sdkman-for-fish' || log_warn "fisher/sdkman-for-fish install failed; run in fish manually."
}

# Key 64 = "Show Spotlight search" in com.apple.symbolichotkeys; frees Cmd+Space for Raycast. Indexing unchanged.
disable_spotlight_hotkey() {
  log_info "Disabling Spotlight keyboard shortcut (Cmd+Space) so Raycast can use it."
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
    '{ enabled = 0; value = { parameters = (65535, 49, 1048576); type = standard; }; }' || log_warn "defaults write for Spotlight hotkey failed."
  log_info "Spotlight hotkey disabled. Log out and back in (or reboot) for the change to take effect."
}

optional_raycast_import() {
  local rc="${SCRIPT_DIR}/raycast/baseline.rayconfig"
  [[ -f "$rc" ]] || return 0
  if ! prompt_yes_no "Import baseline Raycast config (${rc})?" n; then
    return 0
  fi
  open "$rc"
  log_info "Raycast import triggered. Follow the Raycast UI to complete."
}

stow_one_package() {
  local pkg="$1"
  local target_path
  case "$pkg" in
    fish) target_path="${HOME}/.config/fish" ;;
    starship) target_path="${HOME}/.config/starship.toml" ;;
    wezterm) target_path="${HOME}/.config/wezterm" ;;
    tmux) target_path="${HOME}/.tmux.conf" ;;
    tmux-sessionizer-config) target_path="${HOME}/.config/tmux-sessionizer" ;;
    bin) target_path="${HOME}/.local/bin" ;;
    nvim) target_path="${HOME}/.config/nvim" ;;
    *) target_path="" ;;
  esac

  if [[ -n "$target_path" ]] && [[ -e "$target_path" ]] && [[ ! -L "$target_path" ]]; then
    if prompt_yes_no "${target_path} exists and is not a symlink. Move to ${target_path}.bak and stow package '${pkg}'?" n; then
      mv "$target_path" "${target_path}.bak.$(date +%s)"
    else
      log_warn "Skipping stow for package: $pkg"
      return 0
    fi
  fi

  # tmux package also links .tmux-cht-*; ensure parent exists
  mkdir -p "${HOME}/.config"

  (cd "${TARGET_DOTFILES}" && stow --target="${HOME}" "$pkg")
  log_info "Stowed package: $pkg"
}

run_stow_all() {
  command -v stow &>/dev/null || return 0
  local pkgs=(fish starship wezterm tmux tmux-sessionizer-config bin nvim)
  for p in "${pkgs[@]}"; do
    if [[ -d "${TARGET_DOTFILES}/${p}" ]]; then
      stow_one_package "$p"
    else
      log_warn "Stow package dir missing: ${TARGET_DOTFILES}/${p}"
    fi
  done
}

set_fish_default_shell() {
  command -v fish &>/dev/null || return 0
  local fish_path
  fish_path="$(command -v fish)"
  if [[ "${SHELL:-}" == "$fish_path" ]]; then
    log_info "Default shell is already fish."
    return 0
  fi
  if ! prompt_yes_no "Set fish as default login shell (${fish_path})?" n; then
    return 0
  fi
  if ! grep -qF "$fish_path" /etc/shells 2>/dev/null; then
    echo "You may need: sudo sh -c 'echo ${fish_path} >> /etc/shells'"
  fi
  chsh -s "$fish_path" || log_warn "chsh failed; set default shell manually."
}

main() {
  local arg
  BREW_IF_INSTALLED=prompt
  for arg in "$@"; do
    case "$arg" in
      --skip-preflight) SKIP_PREFLIGHT=1 ;;
      --skip-installed-brew)
        if [[ "$BREW_IF_INSTALLED" == "upgrade" ]]; then
          log_error "Cannot use --skip-installed-brew with --upgrade-installed-brew."
          exit 1
        fi
        BREW_IF_INSTALLED=skip
        ;;
      --upgrade-installed-brew)
        if [[ "$BREW_IF_INSTALLED" == "skip" ]]; then
          log_error "Cannot use --upgrade-installed-brew with --skip-installed-brew."
          exit 1
        fi
        BREW_IF_INSTALLED=upgrade
        ;;
      -h|--help)
        echo "Usage: $0 [--skip-preflight] [--skip-installed-brew | --upgrade-installed-brew]"
        echo "  --skip-preflight           Skip conflict / environment checks (CI or advanced users)"
        echo "  --skip-installed-brew      Skip Homebrew formula/cask steps when already installed (no per-package prompts)"
        echo "  --upgrade-installed-brew   Run brew update, then brew upgrade for installed formulae/casks (no per-package prompts)"
        echo "Env: TARGET_DOTFILES (default: \$HOME/6eniu5/dotfiles)"
        exit 0
        ;;
    esac
  done

  log_info "Starting macOS setup (esetup)"
  ensure_homebrew

  if [[ "$BREW_IF_INSTALLED" == "upgrade" ]]; then
    log_info "Running brew update (--upgrade-installed-brew)."
    brew update
  fi

  if [[ "$SKIP_PREFLIGHT" -eq 0 ]]; then
    preflight_environment
  else
    log_warn "Preflight skipped (--skip-preflight)."
  fi

  # Install fish before other formulas so $SHELL can point at fish for all later brew installs
  # (Homebrew uses $SHELL for completion hints and caveat text).
  brew_install_formula fish "fish"
  export_shell_for_homebrew_fish

  local formulas=(
    eza zoxide starship ripgrep bat fd gnu-sed atuin lazygit gh jq stow tmux fzf fnm neovim
  )
  for f in "${formulas[@]}"; do
    brew_install_formula "$f" "$f"
  done

  # bun (try core name first)
  if command -v bun &>/dev/null; then
    case "$BREW_IF_INSTALLED" in
      skip)
        log_info "Skipping bun (already installed)."
        ;;
      upgrade)
        log_info "Upgrading bun via Homebrew..."
        brew upgrade bun 2>/dev/null || brew upgrade oven-sh/bun/bun 2>/dev/null || log_warn "bun upgrade skipped (install from Homebrew for upgrades)."
        record_caveat formula bun
        ;;
      prompt|*)
        if prompt_yes_no "bun already present. Reinstall or proceed with setup step anyway?" n; then
          brew install bun 2>/dev/null || brew install oven-sh/bun/bun
          record_caveat formula bun
        fi
        ;;
    esac
  else
    brew install bun 2>/dev/null || brew install oven-sh/bun/bun
    record_caveat formula bun
  fi

  brew_install_cask wezterm "WezTerm"
  if [[ "$SKIP_ORBSTACK" -eq 0 ]]; then
    brew_install_cask orbstack "OrbStack"
  else
    log_info "Skipping OrbStack install (preflight choice or conflict resolution)."
  fi

  brew_install_cask raycast "Raycast"
  if brew list --cask raycast &>/dev/null; then
    disable_spotlight_hotkey
    optional_raycast_import
  fi

  local fonts=(
    font-cascadia-code font-hack-nerd-font font-meslo-lg-nerd-font font-fira-code
    font-jetbrains-mono font-jetbrains-mono-nerd-font
  )
  for fc in "${fonts[@]}"; do
    brew_install_cask "$fc" "$fc"
  done

  sync_dotfiles_to_home
  init_dotfiles_git

  run_fnm_default_node

  optional_miniconda
  optional_sdkman

  link_homebrew_completions_for_fish

  print_caveat_summary
  if prompt_yes_no "Apply known caveat actions now?" n; then
    apply_known_caveat_actions
  fi

  if prompt_yes_no "Run stow to link ${TARGET_DOTFILES} into \$HOME?" y; then
    run_stow_all
  fi

  if prompt_yes_no "Set fish as default shell?" n; then
    set_fish_default_shell
  fi

  log_info "Done. Dotfiles repo: ${TARGET_DOTFILES}"
  log_info "Open a new terminal or: exec fish"
}

main "$@"
