# Module: rust — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn, record_failed,
# record_manual, prompt_yes_no, and the NONINTERACTIVE global.

# Rust via the official rustup installer (NOT brew's keg-only `rustup`, which
# leaves ~/.cargo/bin empty). rustup-init creates the cargo/rustc/rustfmt
# proxies in ~/.cargo/bin and writes ~/.cargo/env{,.fish} — both of which the
# fish config already puts on PATH / sources, so no shell changes are needed.
# --no-modify-path: fish PATH is handled in config.fish, not the default
# rustup profile edits. rustfmt + clippy ship with the stable profile; the
# rust-analyzer LSP is installed by Mason inside Neovim (mirrors gopls).
rust_present() { command -v rustc &>/dev/null && [[ -d "$HOME/.rustup/toolchains" ]]; }

# Rust is a special case, not an instance of a general "Adapter" (see docs/adr/0001).
# `rustup check` reports a *verdict*, not a version pair — we never compare strings —
# and it covers two things at once (the toolchain and rustup itself).
#
# Watch out: `rustup check` exits 100 when an update is available. Under
# `set -euo pipefail`, an unguarded `out="$(rustup check)"` would abort the script on
# exactly the machines that have something to upgrade.
upgrade_rust() {
  command -v rustup &>/dev/null || return 0

  local out rc=0
  if ! out="$(rustup check 2>&1)"; then
    rc=$?
  fi
  if [[ "$rc" -ne 0 ]] && [[ "$rc" -ne 100 ]]; then
    log_warn "rustup check exited ${rc}."
    record_failed "rust" "rustup check exited ${rc}"
    return 0
  fi

  if ! printf '%s\n' "$out" | grep -q 'update available'; then
    log_info "Rust toolchain up to date."
    return 0
  fi

  printf '%s\n' "$out" | grep 'update available' | while IFS= read -r line; do
    log_info "rustup: ${line}"
  done

  if rustup update; then
    log_info "Rust updated."
  else
    record_failed "rust" "rustup update failed"
  fi
}

run_rustup_default_toolchain() {
  # --upgrade converges an existing toolchain instead of skipping it (the old
  # behaviour left Rust to rot silently).
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if rust_present; then
      upgrade_rust
    else
      record_manual "rust" "absent — --upgrade does not install optional artifacts; run setup.sh without --upgrade"
    fi
    return 0
  fi

  if rust_present; then
    log_info "Rust toolchain already present ($(rustc --version 2>/dev/null)). Skipping rustup-init."
  elif prompt_yes_no "Install Rust stable toolchain via rustup (curl https://sh.rustup.rs | sh -s -- -y)?" y; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs |
      sh -s -- -y --no-modify-path --default-toolchain stable --profile default
  else
    return 0
  fi

  # Bring cargo/rustup proxies onto PATH for the remainder of this run.
  [[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"
  # Defensive: ensure formatter/linter components exist even on a minimal profile.
  command -v rustup &>/dev/null && rustup component add rustfmt clippy 2>/dev/null || true
}
