# Module: claude — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn, record_manual, record_failed, prompt_yes_no, brew_owns_* , and the NONINTERACTIVE / SCRIPT_DIR globals.

# Install Claude Code CLI without Homebrew (Linux/WSL, or any non-brew host). Uses the
# official native installer, which drops a self-updating `claude` binary into ~/.local/bin
# (no Node required) and works on both Linux and macOS. Idempotent: re-running updates in place.
install_claude_code_native() {
  if ! command -v curl &>/dev/null; then
    log_error "curl is required to install Claude Code. Install curl and re-run."
    return 1
  fi
  if command -v claude &>/dev/null; then
    log_info "claude already on PATH: $(command -v claude)."
    if ! prompt_yes_no "Reinstall/update Claude Code via the native installer?" n; then
      return 0
    fi
  fi
  log_info "Installing Claude Code CLI via the official installer (https://claude.ai/install.sh)."
  if curl -fsSL https://claude.ai/install.sh | bash; then
    log_info "Claude Code installed. If 'claude' isn't found, add ~/.local/bin to PATH or open a new shell."
  else
    log_error "Native Claude Code install failed. See https://docs.claude.com/en/docs/claude-code for manual steps."
    return 1
  fi
}

# Anthropic Claude, per host:
#   macOS  — the desktop app (cask `claude` = Chat/Cowork/Code GUI, auto-updates) stays a cask.
#            The CLI uses the NATIVE installer, not the `claude-code` cask. We tried brew-managing
#            it "so Claude Code defers self-updates to brew" — but the native updater wins in
#            practice: it self-updates into ~/.local/share/claude/versions and its ~/.local/bin
#            symlink shadows the older brew copy, so the two race and the report flags claude-code
#            as shadowed forever. One self-updating copy (native) is the only stable end state.
#            --upgrade therefore no longer manages Claude Code; it updates itself.
#   Linux/WSL (or unknown) — no official desktop cask exists, so install just the Claude Code
#            CLI via the native installer. On WSL this is the in-distro Linux CLI; the Windows
#            desktop app (if wanted) is installed separately on the Windows side.
install_claude() {
  [[ -n "$OS_KIND" ]] || detect_os
  if [[ "$OS_KIND" == "macos" ]]; then
    brew_install_cask claude "Claude (desktop app)"
  fi
  install_claude_code_native
}

# Personal fork of mattpocock/skills (the `skills` submodule) symlinked into
# ~/.claude/skills. The installer inits the submodule and, on re-runs, syncs from
# upstream and pushes the fork. See docs/claude-skills/ for the full model.
setup_claude_skills() {
  bash "${SCRIPT_DIR}/scripts/install-claude-skills.sh"
}
