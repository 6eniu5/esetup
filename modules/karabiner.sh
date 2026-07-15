# Module: karabiner — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn, record_manual, prompt_yes_no, brew_owns_cask, and the NONINTERACTIVE / SCRIPT_DIR globals.

optional_karabiner_manager() {
  # Non-Artifact, and destructive: `yarn build` rewrites karabiner.json and
  # `launchctl kickstart` restarts the daemon. Never run unattended.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if brew_owns_cask karabiner-elements; then
      record_manual "karabiner-manager" "config build + daemon restart are destructive; run setup.sh without --upgrade to rebuild"
    fi
    return 0
  fi
  if ! prompt_yes_no "Configure Karabiner Elements from karabiner-manager submodule (install apps, build karabiner.json)?" n; then
    return 0
  fi

  local km_dir="${SCRIPT_DIR}/karabiner-manager"
  if [[ ! -f "${km_dir}/package.json" ]]; then
    if [[ -d "${SCRIPT_DIR}/.git" ]]; then
      log_info "Initializing karabiner-manager submodule..."
      if ! git -C "${SCRIPT_DIR}" submodule update --init --recursive karabiner-manager; then
        log_warn "Submodule init failed. From the esetup repo root run: git submodule update --init --recursive"
        return 1
      fi
    else
      log_warn "karabiner-manager missing at ${km_dir} and ${SCRIPT_DIR} is not a git repo; clone esetup with submodules."
      return 1
    fi
  fi

  if [[ ! -f "${km_dir}/package.json" ]]; then
    log_error "karabiner-manager submodule still missing (no package.json)."
    return 1
  fi

  brew_install_cask karabiner-elements "Karabiner Elements"
  brew_install_cask raycast "Raycast"
  brew_install_cask rectangle "Rectangle"

  mkdir -p "${HOME}/.config/karabiner"
  local kb_path="${HOME}/.config/karabiner/karabiner.json"
  if [[ -f "$kb_path" ]]; then
    local bak="${kb_path}.bak.$(date +%s)"
    cp "$kb_path" "$bak"
    log_info "Backed up existing Karabiner config to ${bak}"
  fi

  if ! (
    cd "$km_dir" || exit 1
    if command -v fnm &>/dev/null; then
      eval "$(fnm env 2>/dev/null)" || true
    fi
    if ! command -v node &>/dev/null; then
      log_error "node not on PATH. Install Node (accept the fnm LTS prompt earlier in this script), then run: cd \"${km_dir}\" && yarn install && yarn build"
      exit 1
    fi
    corepack enable 2>/dev/null || true
    if ! command -v yarn &>/dev/null; then
      log_error "yarn not found after corepack enable. Use Node 16+ with corepack, or install Yarn."
      exit 1
    fi
    yarn install
    yarn build
  ); then
    log_warn "karabiner-manager build failed."
    return 1
  fi

  if launchctl kickstart -k "gui/$(id -u)/org.pqrs.karabiner.karabiner_console_user_server" &>/dev/null; then
    log_info "Reloaded Karabiner Elements user config server."
  else
    log_warn "Could not kickstart Karabiner daemon. Open Karabiner Elements once, or run: launchctl kickstart -k gui/\$(id -u)/org.pqrs.karabiner.karabiner_console_user_server"
  fi
}
