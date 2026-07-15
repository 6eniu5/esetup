# Module: miniconda — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info, record_manual, prompt_yes_no, and the NONINTERACTIVE global.

optional_miniconda() {
  # Deliberately outside the Plan: a py312 -> py314 bump orphans every conda env.
  # This is the one package whose upgrade would need version *ordering*, and we
  # refuse to introduce that (docs/adr/0001).
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if brew_owns_cask miniconda; then
      record_manual "miniconda" "not converged — a major Python bump orphans conda envs; upgrade manually"
    fi
    return 0
  fi
  if ! prompt_yes_no "Install Miniconda (Python version management)?" n; then
    return 0
  fi
  if brew_owns_cask miniconda; then
    if ! prompt_yes_no "Miniconda is already installed. Reinstall?" n; then
      return 0
    fi
  fi
  brew install --cask miniconda
}
