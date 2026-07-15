# Module: sdkman — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info, record_manual, prompt_yes_no, and the NONINTERACTIVE global.

optional_sdkman() {
  # SDKMAN is permanently Manual: `sdk` is a shell function, not a binary; its
  # output is prose, not machine-readable; and silently bumping a Java toolchain
  # under someone's projects is not something to do unattended (docs/adr/0001).
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if [[ -d "${HOME}/.sdkman" ]]; then
      record_manual "sdkman" "candidates are upgraded interactively — run 'sdk upgrade' in a shell"
    fi
    return 0
  fi
  if ! prompt_yes_no "Install SDKMAN! (Java) and fish integrations (fisher + sdkman-for-fish)?" n; then
    return 0
  fi
  if [[ ! -d "${HOME}/.sdkman" ]]; then
    curl -s "https://get.sdkman.io" | bash
  fi
  # fisher + sdkman-for-fish (requires fish)
  fish -c 'curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher reitzig/sdkman-for-fish' || log_warn "fisher/sdkman-for-fish install failed; run in fish manually."
}
