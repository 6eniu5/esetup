# Module: node — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info, record_manual, prompt_yes_no, and the NONINTERACTIVE global.

run_fnm_default_node() {
  command -v fnm &>/dev/null || return 0
  # Node is not an Artifact: fnm can hold many versions at once, so "the installed
  # version" is a set, not a scalar. --upgrade leaves it to fnm.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if command -v node &>/dev/null; then
      log_info "Node present via fnm; --upgrade leaves Node version selection to fnm."
    else
      record_manual "node" "absent — --upgrade does not install optional artifacts; run setup.sh without --upgrade"
    fi
    return 0
  fi
  if prompt_yes_no "Install default Node LTS via fnm (fnm install --lts && fnm default lts-latest)?" y; then
    fnm install --lts
    fnm default lts-latest
  fi
}
