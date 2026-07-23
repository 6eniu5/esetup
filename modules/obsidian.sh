# Module: obsidian — sourced by setup.sh, not executable on its own.
# Depends on shared machinery in setup.sh: log_info/log_warn/log_error, record_manual,
# prompt_yes_no, brew_install_cask, and the NONINTERACTIVE / SCRIPT_DIR / TARGET_DOTFILES globals.

# Lay down a vault's .obsidian config + pinned community-plugin binaries from the
# dotfiles `obsidian/<pkg>` package. This MIRRORS obsidian_copy() in the dotfiles
# ./install — keep the two in step; the vault config is copy-managed there for the
# same reasons (iCloud dislikes symlinks, Obsidian rewrites its own JSON).
#
# Why the data.json dance: plugins/*/data.json holds BOTH a plugin's settings and
# its runtime state — for spaced-repetition that means your FSRS scheduling
# history. It is seeded only when absent, so a fresh machine gets our defaults
# while a re-run never overwrites in-app tweaks or review progress.
#
# Call this BEFORE the generator's deploy: dotfiles lays the baseline, then the
# generator asserts the files it owns on top (e.g. the union-merged
# community-plugins.json). The reverse order silently discards the merge.
obsidian_copy_vault_config() { # $1 = dotfiles package subdir, $2 = vault path
  local src="${TARGET_DOTFILES}/obsidian/$1/vault-obsidian"
  if [[ ! -d "$src" ]]; then
    log_warn "dotfiles obsidian/$1 package not found at ${src}; run the dotfiles ./install once it exists."
    return 1
  fi
  mkdir -p "$2/.obsidian"
  rsync -a --exclude='data.json' "${src}/" "$2/.obsidian/"
  local rel
  while IFS= read -r rel; do
    rel="${rel#./}"
    if [[ ! -f "$2/.obsidian/$rel" ]]; then
      mkdir -p "$2/.obsidian/$(dirname "$rel")"
      cp "${src}/$rel" "$2/.obsidian/$rel"
      log_info "seeded (new): $1/$rel"
    fi
  done < <(cd "$src" && find . -name data.json -path './plugins/*')
  log_info "Copied .obsidian config + pinned plugins into the ${1} vault (plugin settings preserved)."
}

optional_obsidian_habit_tracker() {
  # Non-Artifact, and it writes into the iCloud container: builds the Habits vault
  # from the obsidian-habit-tracker submodule (habits.md -> generated files) and
  # deploys it. The .obsidian config + pinned plugins come from the dotfiles
  # `obsidian` package. See CONTEXT.md and docs/adr/0005. Mirrors the
  # karabiner-manager submodule-generator pattern.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    record_manual "obsidian-habit-tracker" "deploy writes into the iCloud container; run setup.sh interactively"
    return 0
  fi
  if ! prompt_yes_no "Set up the Habits Obsidian vault from the obsidian-habit-tracker submodule?" n; then
    return 0
  fi

  local oht_dir="${SCRIPT_DIR}/obsidian-habit-tracker"
  if [[ ! -f "${oht_dir}/package.json" ]]; then
    if [[ -d "${SCRIPT_DIR}/.git" ]]; then
      log_info "Initializing obsidian-habit-tracker submodule..."
      if ! git -C "${SCRIPT_DIR}" submodule update --init --recursive obsidian-habit-tracker; then
        log_warn "Submodule init failed. From the esetup repo root run: git submodule update --init --recursive"
        return 1
      fi
    else
      log_warn "obsidian-habit-tracker missing at ${oht_dir} and ${SCRIPT_DIR} is not a git repo; clone esetup with submodules."
      return 1
    fi
  fi
  [[ -f "${oht_dir}/package.json" ]] || { log_error "obsidian-habit-tracker submodule still missing (no package.json)."; return 1; }

  # Obsidian.app — Bases needs >= 1.12.4; the cask installs current stable.
  brew_install_cask obsidian "Obsidian"

  if ! command -v bun &>/dev/null; then
    log_error "bun not on PATH. Install bun (earlier brew step), then: cd \"${oht_dir}\" && bun install && bun run sync"
    return 1
  fi

  local vault="${OBSIDIAN_HABITS_VAULT:-$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Habits}"

  # setup_dotfiles ran before the vault existed, so its copy was skipped; do it
  # now, before the generator runs (see obsidian_copy_vault_config).
  mkdir -p "$vault"
  obsidian_copy_vault_config habits "$vault" || true

  if ! (
    cd "$oht_dir" || exit 1
    bun install || exit 1
    bun run sync || exit 1
    bun run deploy --vault "$vault" --apply || exit 1
  ); then
    log_warn "obsidian-habit-tracker build/deploy failed."
    return 1
  fi

  brctl download "$vault" 2>/dev/null || true  # keep iCloud from evicting the vault locally

  if prompt_yes_no "Seed 45 days of sample data to preview the dashboards (removable with --clean)?" n; then
    ( cd "$oht_dir" && bun run seed --vault "$vault" --days 45 --apply ) || log_warn "sample-data seed failed"
  fi

  log_info "Habits vault ready at ${vault}"
  log_warn "Update Obsidian to >= 1.12.4 on Mac AND iPhone (Bases won't work otherwise). On iOS the vault appears under the iCloud heading."
}

optional_obsidian_lingo() {
  # Non-Artifact, writes into the iCloud container: scaffolds the Lingo
  # language-learning vault (templates + .obsidian config) from the obsidian-lingo
  # submodule. Cards are your content (synced via iCloud); deploy never touches
  # them. Mirrors optional_obsidian_habit_tracker. See CONTEXT.md and docs/adr/0006.
  if [[ "$NONINTERACTIVE" -eq 1 ]]; then
    record_manual "obsidian-lingo" "deploy writes into the iCloud container; run setup.sh interactively"
    return 0
  fi
  if ! prompt_yes_no "Set up the Lingo language-learning vault from the obsidian-lingo submodule?" n; then
    return 0
  fi

  local ol_dir="${SCRIPT_DIR}/obsidian-lingo"
  if [[ ! -f "${ol_dir}/package.json" ]]; then
    if [[ -d "${SCRIPT_DIR}/.git" ]]; then
      log_info "Initializing obsidian-lingo submodule..."
      if ! git -C "${SCRIPT_DIR}" submodule update --init --recursive obsidian-lingo; then
        log_warn "Submodule init failed. From the esetup repo root run: git submodule update --init --recursive"
        return 1
      fi
    else
      log_warn "obsidian-lingo missing at ${ol_dir} and ${SCRIPT_DIR} is not a git repo; clone esetup with submodules."
      return 1
    fi
  fi
  [[ -f "${ol_dir}/package.json" ]] || { log_error "obsidian-lingo submodule still missing (no package.json)."; return 1; }

  brew_install_cask obsidian "Obsidian" # idempotent; shared with the Habits step

  if ! command -v bun &>/dev/null; then
    log_error "bun not on PATH. Install bun (earlier brew step), then: cd \"${ol_dir}\" && bun install && bun run sync"
    return 1
  fi

  local vault="${OBSIDIAN_LINGO_VAULT:-$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/Lingo}"

  # Config + plugin binaries FIRST, then the generator on top: deploy union-merges
  # the query plugins the relations feature needs (ADR-0007) into
  # community-plugins.json, and pins the spaced-repetition settings the vault's
  # shape depends on. Copying afterwards would throw both away.
  mkdir -p "$vault"
  obsidian_copy_vault_config lingo "$vault" || true

  if ! (
    cd "$ol_dir" || exit 1
    bun install || exit 1
    bun run sync || exit 1
    bun run deploy --vault "$vault" --apply || exit 1
  ); then
    log_warn "obsidian-lingo build/deploy failed."
    return 1
  fi

  brctl download "$vault" 2>/dev/null || true

  log_info "Lingo vault ready at ${vault}"
  log_warn "Enable the obsidian-spaced-repetition plugin on first open (Restricted mode off). Your cards sync from iCloud."
}
