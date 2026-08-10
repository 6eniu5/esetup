# Module: watch-media — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info, record_manual, prompt_yes_no, and the NONINTERACTIVE global.

run_mlx_whisper_tool() {
  # Local ASR fallback for the /watch skill (skills/6eniu5/watch): transcribes
  # videos that ship no captions. Not an Artifact: uv owns the tool and its venv,
  # so "the installed version" belongs to `uv tool upgrade`, not the Plan.
  [[ "$(uname -m)" == "arm64" ]] || return 0  # MLX runs on Apple Silicon only
  command -v uv &>/dev/null || return 0
  if command -v mlx_whisper &>/dev/null; then
    log_info "mlx_whisper present; uv owns its upgrades (uv tool upgrade mlx-whisper)."
    return 0
  fi
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    record_manual "mlx-whisper" "absent — --upgrade does not install optional artifacts; run setup.sh without --upgrade"
    return 0
  fi
  if prompt_yes_no "Install mlx-whisper via uv (local transcription for the /watch skill)?" y; then
    uv tool install mlx-whisper
  fi
}
