# Module: voiceink — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn, record_manual, record_failed, prompt_yes_no, brew_owns_cask, and the NONINTERACTIVE global.

# VoiceInk: a Source Build (see CONTEXT.md). The brew cask `voiceink` is the paid,
# license-gated pre-built binary (7-day trial, then $25+). The GPL-3.0 source builds
# for free with `make local` (ad-hoc signing, no Apple Developer cert). This is a
# Non-Artifact — no brew receipt, no Plan, no version diff — updated by re-running the
# build (git pull), never `brew upgrade`. Needs FULL Xcode (not just the Command Line
# Tools) plus cmake, which whisper.cpp's XCFramework build shells out to.
optional_voiceink() {
  local build_dir="${HOME}/6eniu5/build/VoiceInk"
  local app_src="${HOME}/Downloads/VoiceInk.app"
  local app_dst="/Applications/VoiceInk.app"

  # Heavy + destructive (multi-minute compile, replaces the .app bundle): never run
  # unattended. Report and leave it to an interactive re-run, exactly like Karabiner.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    if [[ -d "$app_dst" ]]; then
      record_manual "voiceink" "source rebuild is destructive and slow; re-run setup.sh without --upgrade to update"
    else
      record_manual "voiceink" "optional Source Build; not installed unattended — run setup.sh without --upgrade"
    fi
    return 0
  fi

  if ! prompt_yes_no "Build VoiceInk from GPL source (free voice-to-text; requires full Xcode)?" n; then
    return 0
  fi

  # Prerequisite: FULL Xcode, not just the Command Line Tools. `make local` drives
  # xcodebuild, which refuses to run against /Library/Developer/CommandLineTools.
  # Never auto-install Xcode (a ~7GB App Store download + license acceptance).
  local xcode_dir
  xcode_dir="$(xcode-select -p 2>/dev/null || true)"
  if [[ "$xcode_dir" == *"CommandLineTools"* ]] || ! xcodebuild -version &>/dev/null; then
    log_warn "VoiceInk needs full Xcode; active developer dir is '${xcode_dir:-none}'."
    log_warn "Install Xcode from the App Store, then run:"
    log_warn "  sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
    log_warn "  sudo xcodebuild -license accept"
    record_manual "voiceink" "full Xcode required (only Command Line Tools present); install Xcode, select it, accept its license, then re-run"
    return 0
  fi

  # whisper.cpp's build-xcframework.sh shells out to cmake. Route through the normal
  # ownership/Plan machinery so a foreign/owned cmake is handled uniformly.
  brew_install_formula cmake "cmake"

  # A stable clone is the update path a Source Build otherwise lacks. Public repo, so
  # HTTPS — not the kernvex SSH key the dotfiles repo is pinned to.
  mkdir -p "$(dirname "$build_dir")"
  if [[ -d "${build_dir}/.git" ]]; then
    log_info "Updating VoiceInk source at ${build_dir} (git pull --ff-only)."
    if ! git -C "$build_dir" pull --ff-only; then
      log_warn "git pull failed; building the existing checkout."
      record_manual "voiceink" "git pull --ff-only failed in ${build_dir}; built the existing checkout instead"
    fi
  else
    log_info "Cloning VoiceInk source to ${build_dir}."
    if ! git clone https://github.com/Beingpax/VoiceInk.git "$build_dir"; then
      record_manual "voiceink" "git clone failed (network); run: git clone https://github.com/Beingpax/VoiceInk.git ${build_dir}"
      return 0
    fi
  fi

  # `make local` = ad-hoc signing, no Apple Developer cert; drops ~/Downloads/VoiceInk.app.
  log_info "Building VoiceInk (make local) — compiles whisper.cpp, can take a few minutes."
  if ! (cd "$build_dir" && make local); then
    log_warn "VoiceInk build failed."
    record_manual "voiceink" "make local failed — if this is the whisper.cpp/Xcode-26 cmake breakage, drop a prebuilt whisper.xcframework into ~/VoiceInk-Dependencies/whisper.cpp/build-apple/ (see BUILDING.md) and re-run"
    return 0
  fi

  if [[ ! -d "$app_src" ]]; then
    log_warn "make local reported success but ${app_src} is missing."
    record_manual "voiceink" "make local succeeded but ${app_src} not found; check the build output"
    return 0
  fi

  # Swapping a running bundle corrupts the live process (same hazard as cask_app_running).
  if pgrep -qf "/Applications/VoiceInk.app/Contents/MacOS/"; then
    log_warn "VoiceInk is running; leaving the fresh build at ${app_src}."
    record_manual "voiceink" "VoiceInk is running; quit it and re-run to install the freshly built app from ${app_src}"
    return 0
  fi

  if [[ -d "$app_dst" ]]; then
    local bak="${app_dst}.bak.$(date +%s)"
    mv "$app_dst" "$bak"
    log_info "Backed up existing ${app_dst} to ${bak}."
  fi
  mv "$app_src" "$app_dst"
  log_info "Installed VoiceInk to ${app_dst}. First launch: right-click → Open (ad-hoc signed; Gatekeeper prompts once)."

  # The installed .app embeds everything it needs, so the app build output is throwaway.
  # Prune it (~1.5G) but KEEP ~/VoiceInk-Dependencies (the whisper.cpp cache is slow to
  # regenerate and re-risks the Xcode-26 cmake breakage) and the lean source clone (the
  # update path). Only runs after a successful install, so a failed build keeps its cache.
  if [[ -d "${build_dir}/.local-build" ]]; then
    rm -rf "${build_dir}/.local-build"
    log_info "Pruned VoiceInk app build output (${build_dir}/.local-build)."
  fi
}
