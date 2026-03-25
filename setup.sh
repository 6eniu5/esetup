#!/usr/bin/env bash
# macOS bootstrap: Homebrew, CLI tools, runtimes, dotfiles (stow), submodules.
# 2-space indent; guard clauses; interactive prompts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_DOTFILES="${SCRIPT_DIR}/dotfiles"
TARGET_DOTFILES="${HOME}/dotfiles"

# Set by preflight_environment; 1 = do not install OrbStack cask this run
SKIP_ORBSTACK=0
SKIP_PREFLIGHT=0

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

# Returns 0 = proceed install, 1 = skip
prompt_install_or_reinstall() {
  local name="$1"
  local check_cmd="$2"
  if eval "$check_cmd" &>/dev/null; then
    if prompt_yes_no "${name} already present. Reinstall or proceed with setup step anyway?" n; then
      return 0
    fi
    return 1
  fi
  return 0
}

brew_install_formula() {
  local formula="$1"
  local desc="${2:-$formula}"
  if ! prompt_install_or_reinstall "$desc" "brew list --formula \"$formula\" &>/dev/null"; then
    log_warn "Skipping formula: $formula"
    return 0
  fi
  brew install "$formula"
}

brew_install_cask() {
  local cask="$1"
  local desc="${2:-$cask}"
  if ! prompt_install_or_reinstall "$desc" "brew list --cask \"$cask\" &>/dev/null"; then
    log_warn "Skipping cask: $cask"
    return 0
  fi
  brew install --cask "$cask"
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
  for arg in "$@"; do
    case "$arg" in
      --skip-preflight) SKIP_PREFLIGHT=1 ;;
      -h|--help)
        echo "Usage: $0 [--skip-preflight]"
        echo "  --skip-preflight  Skip conflict / environment checks (CI or advanced users)"
        exit 0
        ;;
    esac
  done

  log_info "Starting macOS setup (esetup)"
  ensure_homebrew

  if [[ "$SKIP_PREFLIGHT" -eq 0 ]]; then
    preflight_environment
  else
    log_warn "Preflight skipped (--skip-preflight)."
  fi

  local formulas=(
    eza zoxide starship ripgrep bat fd gnu-sed atuin lazygit gh jq stow tmux fzf fnm neovim
  )
  for f in "${formulas[@]}"; do
    brew_install_formula "$f" "$f"
  done

  # bun (try core name first)
  if prompt_install_or_reinstall "bun" "command -v bun &>/dev/null"; then
    brew install bun 2>/dev/null || brew install oven-sh/bun/bun
  fi

  brew_install_cask wezterm "WezTerm"
  if [[ "$SKIP_ORBSTACK" -eq 0 ]]; then
    brew_install_cask orbstack "OrbStack"
  else
    log_info "Skipping OrbStack install (preflight choice or conflict resolution)."
  fi
  brew_install_formula fish "fish"

  local fonts=(
    font-cascadia-code font-hack-nerd-font font-meslo-lg-nerd-font font-fira-code
  )
  for fc in "${fonts[@]}"; do
    brew_install_cask "$fc" "$fc"
  done

  sync_dotfiles_to_home
  init_dotfiles_git

  run_fnm_default_node

  optional_miniconda
  optional_sdkman

  if prompt_yes_no "Run stow to link ~/dotfiles into \$HOME?" y; then
    run_stow_all
  fi

  if prompt_yes_no "Set fish as default shell?" n; then
    set_fish_default_shell
  fi

  log_info "Done. Dotfiles repo: ${TARGET_DOTFILES}"
  log_info "Open a new terminal or: exec fish"
}

main "$@"
