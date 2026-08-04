# Module: gcloud — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: brew_owns_cask, brew_install_cask, prompt_yes_no,
# and the NONINTERACTIVE global.

# The Google Cloud SDK. Declared under its *current* token: brew renamed
# google-cloud-sdk -> gcloud-cli, and `brew list --cask` prints only the new name, so
# declaring the old one would leave brew_owns_cask false forever and reprompt on every
# run. `brew install --cask google-cloud-sdk` still resolves; ownership is what the
# rename breaks.
#
# The cask copies the SDK into $(brew --prefix)/share/google-cloud-sdk and symlinks
# gcloud/gsutil/bq (plus the two credential helpers) into bin, so nothing needs a PATH
# edit -- its caveat only covers extra components installed later via
# `gcloud components install`, which land beside the SDK rather than in bin.
optional_gcloud() {
  # Optional means --upgrade must never *introduce* it on a machine that declined it.
  # But once it is Brew-owned it is an ordinary cask with an ordinary Version Diff --
  # unlike miniconda or sdkman there is no hazard in converging it -- so hand it to the
  # normal Step and let the Plan decide.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    brew_owns_cask gcloud-cli || return 0
    brew_install_cask gcloud-cli "Google Cloud SDK (gcloud)"
    return 0
  fi

  # Ask the opt-in question only when it is absent; when it is already installed the
  # shared Step asks its own "already present, reinstall?" question, and asking both
  # would be two prompts for one decision.
  if ! brew_owns_cask gcloud-cli; then
    if ! prompt_yes_no "Install the Google Cloud SDK (gcloud, gsutil, bq)?" n; then
      return 0
    fi
  fi

  brew_install_cask gcloud-cli "Google Cloud SDK (gcloud)"
}
