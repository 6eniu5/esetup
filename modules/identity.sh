# Module: identity — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info, log_warn, record_manual,
# record_failed, and MANAGER_REPO.

# Per-folder identity routing. The generator lives in a PRIVATE sibling repo
# (see scripts/clone-private-repos.sh), because the map of which folder belongs
# to which client is exactly the fact this public repo must never learn.
#
# The work splits cleanly along this script's own model:
#
#   apply   — writes non-secret generated config, idempotent, prompts for
#             nothing. A Non-Artifact: it changes the machine and has no version
#             to diff, so --upgrade runs it like any other idempotent step.
#
#   restore — decrypts vaults and re-runs browser logins. It needs a separate
#             passphrase per identity and a browser, so it can never converge
#             unattended. That makes it Manual with a Reason, not a prompt in
#             the middle of an unattended run.
#
# Ordering matters: this must run AFTER setup_dotfiles. `apply` writes into
# ~/.config/git/ and ~/.config/fish/conf.d/, and it relies on stow having already
# put ~/.gitconfig in place with its `[include] local.inc` line. Run earlier, it
# would write into a tree stow is about to replace.
#
# Absent access to the private repo, this is skipped and the run still succeeds —
# a machine without the repo should get a working esetup missing one feature, not
# a failed bootstrap.
setup_identity_routing() {
  local repo="${MANAGER_REPO}/identity"
  local bin="${repo}/bin/identity"

  # clone-private-repos.sh is idempotent and exits 0 when a repo is unreachable;
  # only call it when we actually need it, to keep its output off a normal run.
  if [[ ! -x "$bin" ]]; then
    bash "${MANAGER_REPO}/scripts/clone-private-repos.sh" || true
  fi

  if [[ ! -x "$bin" ]]; then
    log_info "Identity routing: private repo unavailable, skipping (per-folder git/gh/cloud identity will not be configured)."
    return 0
  fi

  log_info "Identity routing: generating per-folder git/gh/cloud config"
  if ! "$bin" apply; then
    record_failed "identity" "identity apply failed"
    return 1
  fi

  # Check even when nothing was generated. The whole failure mode here is
  # silence — a wrong-account CLI reports private repos as nonexistent rather
  # than erroring — so a run that never verifies is worth very little.
  if ! "$bin" check >/dev/null 2>&1; then
    record_manual "identity" "identity check reports drift; run '${bin} check' to see it"
  fi

  # Keys are absent on a fresh machine by design: vaults are encrypted and the
  # passphrases are the user's. Name it rather than prompting.
  local missing
  missing="$("$bin" keys-missing || true)"
  if [[ -n "$missing" ]]; then
    record_manual "identity-restore" "SSH keys not yet decrypted for: $(echo "$missing" | tr '\n' ' ')— run '${bin} restore' (needs a vault passphrase per identity, then a browser login per tool)"
  fi
}
