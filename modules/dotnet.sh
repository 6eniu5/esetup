# Module: dotnet — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: brew_owns_formula, brew_owns_cask,
# brew_install_formula, brew_install_cask, prompt_yes_no, record_manual, log_*, and the
# NONINTERACTIVE global.

# The .NET SDK, which is also how you get NuGet: `dotnet nuget` and `dotnet add package`
# are built in. Deliberately *not* the standalone `nuget` formula -- that is the legacy
# nuget.exe CLI and it depends on `mono`, roughly a gigabyte of runtime, to run a tool
# the SDK already contains.
#
# Two packagings, and the choice is per-machine because only one of them supports MAUI:
#
#   cask `dotnet-sdk`  Microsoft's official .pkg. Installs to /usr/local/share/dotnet
#                      (root-owned, so it asks for a sudo password mid-install) and
#                      symlinks dotnet/dnx into the brew prefix. The only flavour that
#                      can run `dotnet workload install maui`.
#   formula `dotnet`   An ordinary keg, no sudo, and it fits the ownership model better
#                      (is_foreign_formula catches a pre-existing dotnet before we act,
#                      check_shadowed_formula after). But it is a *source build* of the
#                      dotnet/dotnet VMR -- see the formula's own url -- and MAUI on a
#                      source-built SDK is not a configuration Microsoft supports.
#                      Workload manifests do resolve against it and `dotnet workload
#                      search maui` does list the workloads, so the failure (if any) is
#                      not upfront; it surfaces later, in a build, looking like a broken
#                      project. Take the cask on any machine that must ship MAUI.
#
# Pick with ESETUP_DOTNET_FLAVOR=cask|formula; unset asks interactively. A machine that
# needs MAUI wants cask.
ESETUP_DOTNET_FLAVOR="${ESETUP_DOTNET_FLAVOR:-}"

# Both flavours symlink a `dotnet` into $(brew --prefix)/bin, so installing the second
# over the first is a collision, not a coexistence. Detect rather than let brew lose.
dotnet_both_flavours_owned() {
  brew_owns_formula dotnet && brew_owns_cask dotnet-sdk
}

# Where the SDK actually lives, which decides whether a workload write needs sudo. Two
# known locations rather than resolving symlinks: the cask's root is root-owned, the
# formula's sits in the user-owned brew prefix.
dotnet_sdk_root() {
  if [[ -d "/usr/local/share/dotnet" ]]; then
    printf '%s\n' "/usr/local/share/dotnet"
    return 0
  fi
  printf '%s\n' "$(brew --prefix)/opt/dotnet/libexec"
}

dotnet_maui_installed() {
  command -v dotnet &>/dev/null || return 1
  dotnet workload list 2>/dev/null | grep -qiE '^[[:space:]]*maui'
}

# The MAUI workload is a Non-Artifact: no brew receipt and no Version Diff we can read,
# so it never enters a Plan and `dotnet workload update` stays the user's call.
optional_maui_workload() {
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    dotnet_maui_installed && record_manual "maui" "workloads are outside the Plan — run 'dotnet workload update' yourself"
    return 0
  fi

  if dotnet_maui_installed; then
    log_info "MAUI workload already installed."
    return 0
  fi

  # Cost named in the prompt: this is a large download, wants a full Xcode for the
  # iOS/Mac Catalyst targets, and needs sudo wherever the SDK root is root-owned.
  if ! prompt_yes_no "Install the MAUI workload now (dotnet workload install maui; large, needs Xcode, may ask for sudo)?" n; then
    log_info "Skipped. Install it later with: dotnet workload install maui"
    return 0
  fi

  # iOS and Mac Catalyst need a full Xcode, not just the Command Line Tools. Checking
  # first turns a long download that ends in a build error into an upfront Reason.
  if ! xcode-select -p &>/dev/null; then
    log_warn "No Xcode selected; MAUI's iOS/Mac Catalyst targets will not build."
    record_manual "maui" "no Xcode selected (xcode-select -p failed) — install Xcode, then: dotnet workload install maui"
    return 0
  fi

  local root
  root="$(dotnet_sdk_root)"
  if [[ -w "$root" ]]; then
    dotnet workload install maui || record_failed "maui" "dotnet workload install maui failed"
    return 0
  fi

  log_info "${root} is not writable; the workload install needs sudo."
  sudo dotnet workload install maui || record_failed "maui" "sudo dotnet workload install maui failed"
}

optional_dotnet() {
  # Two SDKs fighting over one symlink is a machine problem, not something to resolve
  # unattended -- name it and change nothing.
  if dotnet_both_flavours_owned; then
    record_manual "dotnet" "both flavours installed (formula 'dotnet' and cask 'dotnet-sdk'); they collide on $(brew --prefix)/bin/dotnet — uninstall one"
    return 0
  fi

  # Optional means --upgrade must never *introduce* it on a machine that declined it.
  # Converge whichever flavour is already there; workloads stay untouched.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if brew_owns_cask dotnet-sdk; then
      brew_install_cask dotnet-sdk ".NET SDK (official)"
    elif brew_owns_formula dotnet; then
      brew_install_formula dotnet ".NET SDK (Homebrew source build)"
    else
      return 0
    fi
    optional_maui_workload
    return 0
  fi

  # An installed flavour is the answer to "which flavour" -- never re-ask, and never let
  # ESETUP_DOTNET_FLAVOR silently install the other one alongside it.
  local flavour=""
  if brew_owns_cask dotnet-sdk; then
    flavour=cask
  elif brew_owns_formula dotnet; then
    flavour=formula
  else
    if ! prompt_yes_no "Install the .NET SDK (includes NuGet: dotnet nuget / dotnet add package)?" n; then
      return 0
    fi
    flavour="$ESETUP_DOTNET_FLAVOR"
    if [[ -z "$flavour" ]]; then
      # The MAUI answer is the whole reason this menu exists, so it leads -- picking
      # option 2 on a machine that builds MAUI means uninstalling and starting over.
      echo
      echo "  Which .NET SDK? For MAUI (iOS / Android / Mac Catalyst), choose 1."
      echo
      echo "  1) Official Microsoft SDK  — cask 'dotnet-sdk'. Microsoft's own build, and"
      echo "     the supported SDK for MAUI workloads. Installs to /usr/local/share/dotnet"
      echo "     and asks for a sudo password."
      echo "  2) Homebrew formula       — formula 'dotnet'. No sudo, upgrades as an"
      echo "     ordinary formula, but it is a source build and MAUI on it is NOT a"
      echo "     supported configuration. The workloads still list and their manifests"
      echo "     still install, so a problem shows up in a build, not at install time."
      echo
      read -r -p "Choose [1-2, default 1 (the MAUI-supported one)]: " dotnet_choice || true
      case "${dotnet_choice:-1}" in
        2) flavour=formula ;;
        *) flavour=cask ;;
      esac
    fi
  fi

  case "$flavour" in
    cask)
      brew_install_cask dotnet-sdk ".NET SDK (official)"
      # Only reached with the cask, so the MAUI offer is never made on an SDK that
      # cannot honour it.
      if brew_owns_cask dotnet-sdk; then
        log_info "Official Microsoft SDK: the supported flavour for MAUI workloads."
        optional_maui_workload
      fi
      ;;
    formula)
      brew_install_formula dotnet ".NET SDK (Homebrew source build)"
      # Said on every run that lands here, not only on a fresh install: a machine can
      # acquire a MAUI project long after the SDK was chosen, and the failure mode
      # otherwise looks like a broken project rather than a wrong SDK.
      log_warn "This is Homebrew's source build: MAUI on it is not a supported configuration."
      log_warn "For MAUI: brew uninstall dotnet, then ESETUP_DOTNET_FLAVOR=cask ./setup.sh"
      ;;
    *)
      log_error "Unknown ESETUP_DOTNET_FLAVOR: '${flavour}' (expected 'cask' or 'formula')."
      record_manual "dotnet" "unknown ESETUP_DOTNET_FLAVOR='${flavour}'; nothing installed"
      ;;
  esac
  return 0
}
