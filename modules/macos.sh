# Module: macos — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn, record_manual, prompt_yes_no, and the NONINTERACTIVE global.

# Key 64 = "Show Spotlight search" in com.apple.symbolichotkeys; frees Cmd+Space for Raycast. Indexing unchanged.
disable_spotlight_hotkey() {
  log_info "Disabling Spotlight keyboard shortcut (Cmd+Space) so Raycast can use it."
  defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
    '{ enabled = 0; value = { parameters = (65535, 49, 1048576); type = standard; }; }' || log_warn "defaults write for Spotlight hotkey failed."
  log_info "Spotlight hotkey disabled. Log out and back in (or reboot) for the change to take effect."
}

set_fish_default_shell() {
  command -v fish &>/dev/null || return 0
  local fish_path
  fish_path="$(command -v fish)"
  # NOT $SHELL -- export_shell_for_homebrew_fish has already overwritten it with fish.
  if [[ "$ESETUP_ORIGINAL_SHELL" == "$fish_path" ]]; then
    log_info "Default shell is already fish."
    return 0
  fi
  # chsh is destructive and is not an upgrade.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    record_manual "fish" "default login shell is not fish; chsh is destructive — run setup.sh without --upgrade"
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
