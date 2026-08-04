# Module: dotfiles — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn, record_manual, prompt_yes_no, ensure_* helpers, and the TARGET_DOTFILES / NONINTERACTIVE / SCRIPT_DIR globals.

# git wrapper: use the kernvex SSH identity if the vault decrypted it, else the default
# SSH/agent. NEVER set an empty GIT_SSH_COMMAND — that breaks the fetch/clone.
_dotfiles_git() {
  if [[ -f "$ESETUP_SSH_IDENTITY" ]]; then
    GIT_SSH_COMMAND="ssh -F /dev/null -i $ESETUP_SSH_IDENTITY -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=$HOME/.ssh/known_hosts" git "$@"
  else
    git "$@"
  fi
}

setup_dotfiles() {
  if [[ -d "${TARGET_DOTFILES}/.git" ]]; then
    log_info "Updating dotfiles repo (${TARGET_DOTFILES})..."
    _dotfiles_git -C "${TARGET_DOTFILES}" pull --ff-only 2>/dev/null \
      || log_warn "dotfiles pull skipped (up to date, local changes, or offline); using the local checkout."
    _dotfiles_git -C "${TARGET_DOTFILES}" submodule update --init --recursive 2>/dev/null || true
  elif [[ -e "${TARGET_DOTFILES}" ]]; then
    log_warn "${TARGET_DOTFILES} exists but is not the dotfiles repo."
    record_manual "dotfiles" "${TARGET_DOTFILES} exists and is not a git clone; move it aside and re-run"
    return 0
  else
    log_info "Cloning ${DOTFILES_REPO} -> ${TARGET_DOTFILES}..."
    if ! _dotfiles_git clone --recurse-submodules "$DOTFILES_REPO" "${TARGET_DOTFILES}"; then
      record_failed "dotfiles" "git clone ${DOTFILES_REPO} failed (SSH / network)"
      return 0
    fi
  fi

  # Self-installing: the repo stows its packages into $HOME with --no-folding.
  if [[ -x "${TARGET_DOTFILES}/install" ]]; then
    if ! ( cd "${TARGET_DOTFILES}" && ./install ); then
      record_failed "dotfiles" "dotfiles ./install failed"
    fi
  else
    record_failed "dotfiles" "dotfiles repo has no executable ./install"
  fi

  apply_dotfiles_artifacts
}

# Non-stowed artifact areas the installer applies rather than symlinks.
apply_dotfiles_artifacts() {
  # Raycast: import the baseline export if present (opens Raycast to handle the import).
  local rc="${TARGET_DOTFILES}/raycast/baseline.rayconfig"
  if [[ -f "$rc" ]] && brew_owns_cask raycast; then
    if [[ "$NONINTERACTIVE" -eq 1 ]]; then
      record_manual "raycast" "baseline export at ${rc}; import it via Raycast when convenient"
    elif prompt_yes_no "Import baseline Raycast config (${rc})?" n; then
      open "$rc" && log_info "Raycast import triggered; follow the Raycast UI to finish."
    fi
  fi
  # Keyboard: Advantage360 SmartSet layouts live in the repo; loading them is manual in the app.
  if [[ -d "${TARGET_DOTFILES}/keyboard" ]]; then
    log_info "Advantage360 SmartSet layouts: ${TARGET_DOTFILES}/keyboard (load via the SmartSet app)."
  fi
}
