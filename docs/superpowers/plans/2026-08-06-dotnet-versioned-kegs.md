# Versioned .NET SDK Kegs Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make versioned .NET SDK kegs (`dotnet@8`, …) managed esetup Artifacts, with a generated `dotnetN` fish function per installed keg.

**Architecture:** One new module function `optional_dotnet_versioned()` in `modules/dotnet.sh` (converges owned `dotnet@*` kegs every run via the existing `brew_install_formula` machinery; introduces new ones only interactively), one new call line in `setup.sh` `main()`, and one new detection + emission in `scripts/apply-toolchain-env.sh` that turns each keg found on disk into a fish function in the generated `esetup-toolchains.fish`.

**Tech Stack:** bash (macOS `/usr/bin/env bash`, 3.2-compatible), Homebrew, fish (generated config only), jq (already a dependency, always guarded with `command -v`).

**Spec:** `docs/superpowers/specs/2026-08-06-dotnet-versioned-kegs-design.md`

## Global Constraints

- bash 3.2 compatible: no `mapfile`, no associative arrays, no `${var,,}`.
- Style per `setup.sh` header: 2-space indent, guard clauses, interactive prompts.
- Modules are `source`d by `setup.sh`, never executed: no shebang, no exec bit on `modules/dotnet.sh`.
- Terminology is load-bearing: **Manual** = knowingly left alone, always with a Reason; **Failed** = attempted and broke, makes the run exit nonzero.
- `--upgrade` (`NONINTERACTIVE=1`) must never *introduce* an optional Artifact, only converge what is owned.
- `esetup-toolchains.fish` is generated wholesale; nothing appends to it and nobody edits it by hand.
- The test harness in Task 1 is throwaway (lives in `/tmp`), not committed.

---

### Task 1: `optional_dotnet_versioned()` in `modules/dotnet.sh`

**Files:**
- Modify: `modules/dotnet.sh` (header comment block ends line 28; add variable + function after line 29, i.e. after `ESETUP_DOTNET_FLAVOR="${ESETUP_DOTNET_FLAVOR:-}"`)
- Test: `/tmp/dotnet-versioned-harness.sh` (throwaway, not committed)

**Interfaces:**
- Consumes (globals/helpers defined in `setup.sh`, available because modules are sourced into its process): `OWNED_FORMULAE` (newline-separated formula names), `NONINTERACTIVE` (0/1), `brew_owns_formula NAME`, `brew_install_formula NAME DESC`, `record_manual NAME REASON`, `prompt_yes_no MSG DEFAULT`, `log_info`.
- Produces: `optional_dotnet_versioned` (no args, always returns 0) and `dotnet_keg_unavailable_reason KEG` (prints a Reason and returns 0 if the keg cannot be installed; returns 1 if installable). Task 2 calls `optional_dotnet_versioned` from `main()`.

- [ ] **Step 1: Write the failing harness**

Write `/tmp/dotnet-versioned-harness.sh`:

```bash
#!/usr/bin/env bash
# Throwaway harness for optional_dotnet_versioned. Stubs the setup.sh machinery
# the module consumes, sources the module, and checks each behavioral promise.
set -u
cd "$(dirname "$0")"
ESETUP="$HOME/Documents/Projects/setup/esetup"

FAILURES=0
assert_eq() {  # got want label
  if [[ "$1" == "$2" ]]; then
    echo "ok: $3"
  else
    echo "FAIL: $3 — got '$1', want '$2'"
    FAILURES=$((FAILURES + 1))
  fi
}

# --- stubs for the setup.sh machinery ---------------------------------------
INSTALL_CALLS=""
MANUAL_ENTRIES=""
PROMPT_RC=0        # prompt_yes_no verdict: 0 = yes, 1 = no
BREW_INFO_JSON=""  # empty = `brew info` fails (unknown formula)

log_info() { :; }
log_warn() { :; }
prompt_yes_no() { return "$PROMPT_RC"; }
brew_install_formula() { INSTALL_CALLS="${INSTALL_CALLS} $1"; }
record_manual() { MANUAL_ENTRIES="${MANUAL_ENTRIES} $1"; }
brew_owns_formula() { printf '%s\n' "$OWNED_FORMULAE" | grep -qxF -- "$1"; }
brew() {
  # Only `brew info --json=v2 --formula NAME` is reachable from the module.
  [[ -n "$BREW_INFO_JSON" ]] || return 1
  printf '%s\n' "$BREW_INFO_JSON"
}

# shellcheck disable=SC1091
source "$ESETUP/modules/dotnet.sh"

reset() { INSTALL_CALLS=""; MANUAL_ENTRIES=""; PROMPT_RC=0; BREW_INFO_JSON=""; }

# 1. Owned kegs converge on every run, --upgrade included; nothing else installs.
reset; OWNED_FORMULAE=$'git\ndotnet@8\njq'; NONINTERACTIVE=1; ESETUP_DOTNET_VERSIONS=""
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" " dotnet@8" "converges owned keg under NONINTERACTIVE"

# 2. --upgrade never introduces, even with the variable set.
reset; OWNED_FORMULAE="git"; NONINTERACTIVE=1; ESETUP_DOTNET_VERSIONS="8"
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" "" "NONINTERACTIVE never introduces"

# 3. Interactive + variable set + gate accepted -> installs the missing keg.
reset; OWNED_FORMULAE="git"; NONINTERACTIVE=0; ESETUP_DOTNET_VERSIONS="8"
BREW_INFO_JSON='{"formulae":[{"disabled":false}]}'
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" " dotnet@8" "interactive install of wanted keg"

# 4. Gate declined -> nothing happens.
reset; OWNED_FORMULAE="git"; NONINTERACTIVE=0; ESETUP_DOTNET_VERSIONS="8"; PROMPT_RC=1
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" "" "declined gate installs nothing"

# 5. Unknown formula -> Manual with a Reason, no install attempt.
reset; OWNED_FORMULAE="git"; NONINTERACTIVE=0; ESETUP_DOTNET_VERSIONS="99"
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" "" "unknown formula not installed"
assert_eq "$MANUAL_ENTRIES" " dotnet@99" "unknown formula recorded Manual"

# 6. Disabled keg (dotnet@6 is EOL) -> Manual, no install attempt.
reset; OWNED_FORMULAE="git"; NONINTERACTIVE=0; ESETUP_DOTNET_VERSIONS="6"
BREW_INFO_JSON='{"formulae":[{"disabled":true}]}'
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" "" "disabled formula not installed"
assert_eq "$MANUAL_ENTRIES" " dotnet@6" "disabled formula recorded Manual"

# 7. Already-owned wanted version is not re-proposed.
reset; OWNED_FORMULAE=$'git\ndotnet@8'; NONINTERACTIVE=0; ESETUP_DOTNET_VERSIONS="8"
optional_dotnet_versioned
assert_eq "$INSTALL_CALLS" " dotnet@8" "owned keg converged once, not proposed again"

echo
[[ "$FAILURES" -eq 0 ]] && echo "ALL PASS" || echo "$FAILURES FAILURE(S)"
exit "$FAILURES"
```

- [ ] **Step 2: Run the harness to verify it fails**

Run: `bash /tmp/dotnet-versioned-harness.sh`
Expected: FAIL — `optional_dotnet_versioned: command not found` (nonzero exit).

- [ ] **Step 3: Implement the variable and function**

In `modules/dotnet.sh`, insert immediately after the line `ESETUP_DOTNET_FLAVOR="${ESETUP_DOTNET_FLAVOR:-}"`:

```bash

# Versioned kegs (dotnet@8, dotnet@9, …) ride alongside whichever flavour was
# chosen. They exist because work repos pin majors older than the primary SDK:
# any newer SDK *builds* net8.0, but *running* on the pinned major needs its
# runtime, and DOTNET_ROLL_FORWARD=LatestMajor means testing on a runtime
# production never uses. Keg-only, so nothing links into $(brew --prefix)/bin
# and neither flavour is disturbed — which also means PATH never reaches them;
# apply-toolchain-env.sh generates a `dotnetN` fish function per detected keg.
#
# Declare with ESETUP_DOTNET_VERSIONS (space-separated majors, e.g. "8");
# unset asks interactively. Owned kegs converge on every run; --upgrade never
# introduces one.
ESETUP_DOTNET_VERSIONS="${ESETUP_DOTNET_VERSIONS:-}"

# A typo'd major or a disabled keg (dotnet@6 is EOL upstream) is user error to
# name, not an install to attempt — attempting would land it in Failed, and
# Failed means something broke. Prints the Reason and returns 0 when the keg
# cannot be installed; returns 1 when it can.
dotnet_keg_unavailable_reason() {
  local keg="$1" json
  if ! json="$(brew info --json=v2 --formula "$keg" 2>/dev/null)"; then
    printf 'no such formula — check the major in ESETUP_DOTNET_VERSIONS'
    return 0
  fi
  if command -v jq &>/dev/null \
    && [[ "$(printf '%s\n' "$json" | jq -r '.formulae[0].disabled // false')" == "true" ]]; then
    printf 'disabled in Homebrew (EOL upstream); cannot install'
    return 0
  fi
  return 1
}

# Orthogonal to the flavour choice on purpose: kegs never touch the shared
# $(brew --prefix)/bin/dotnet symlink, so they converge even on a machine stuck
# in the both-flavours collision above.
optional_dotnet_versioned() {
  local keg v wanted missing reason

  # Converge what is owned, --upgrade included. brew_install_formula supplies
  # Plan lookup, upgrade, pinned->Manual, and the shadow check.
  while IFS= read -r keg; do
    [[ "$keg" == dotnet@* ]] || continue
    brew_install_formula "$keg" ".NET SDK ${keg#dotnet@} (versioned keg)"
  done <<<"$OWNED_FORMULAE"

  # Optional means --upgrade must never introduce it on a machine that
  # declined it — with or without ESETUP_DOTNET_VERSIONS set.
  [[ "$NONINTERACTIVE" -eq 1 ]] && return 0

  wanted="$ESETUP_DOTNET_VERSIONS"
  if [[ -z "$wanted" ]]; then
    read -r -p "Versioned .NET SDK kegs to add (space-separated majors, e.g. '8'; empty to skip): " wanted || true
  fi

  missing=""
  for v in $wanted; do
    brew_owns_formula "dotnet@${v}" && continue
    missing="${missing} dotnet@${v}"
  done
  missing="${missing# }"
  [[ -n "$missing" ]] || return 0

  if ! prompt_yes_no "Install versioned .NET SDK keg(s): ${missing}?" y; then
    log_info "Skipped. Set ESETUP_DOTNET_VERSIONS or answer the prompt on a later run."
    return 0
  fi

  for keg in $missing; do
    if reason="$(dotnet_keg_unavailable_reason "$keg")"; then
      record_manual "$keg" "$reason"
      continue
    fi
    brew_install_formula "$keg" ".NET SDK ${keg#dotnet@} (versioned keg)"
  done
  return 0
}
```

- [ ] **Step 4: Run the harness to verify it passes**

Run: `bash -n modules/dotnet.sh && bash /tmp/dotnet-versioned-harness.sh`
Expected: `ALL PASS`, exit 0.

- [ ] **Step 5: Commit**

```bash
cd ~/Documents/Projects/setup/esetup
git add modules/dotnet.sh
git commit -m "feat(dotnet): manage versioned SDK kegs (dotnet@N)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 2: Wire `optional_dotnet_versioned` into `main()`

**Files:**
- Modify: `setup.sh` (~line 1119–1124, the `optional_gcloud` / `optional_dotnet` block)

**Interfaces:**
- Consumes: `optional_dotnet_versioned` from Task 1.
- Produces: the call site; nothing later depends on it.

- [ ] **Step 1: Edit the call block**

In `setup.sh` `main()`, replace:

```bash
  # No `|| record_failed` on these two, unlike their neighbours: they go through
  # brew_install_cask / brew_install_formula, which record their own Failed entries and
  # return 0 by design (one broken Artifact must not stop the rest). A wrapper here
  # would be unreachable.
  optional_gcloud
  optional_dotnet
```

with:

```bash
  # No `|| record_failed` on these three, unlike their neighbours: they go through
  # brew_install_cask / brew_install_formula, which record their own Failed entries and
  # return 0 by design (one broken Artifact must not stop the rest). A wrapper here
  # would be unreachable.
  optional_gcloud
  optional_dotnet
  optional_dotnet_versioned
```

- [ ] **Step 2: Verify syntax and ordering**

Run: `bash -n setup.sh && grep -n -A2 'optional_dotnet$' setup.sh | head -6`
Expected: no syntax errors; `optional_dotnet_versioned` on the line after `optional_dotnet`, both before the `optional_miniconda` line and before `apply_toolchain_env` (which must stay last so it sees what the run left on disk).

- [ ] **Step 3: Commit**

```bash
cd ~/Documents/Projects/setup/esetup
git add setup.sh
git commit -m "feat(dotnet): call optional_dotnet_versioned from main

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 3: `dotnetN` fish functions in `apply-toolchain-env.sh`

**Files:**
- Modify: `scripts/apply-toolchain-env.sh` — header table (~line 8–12), new `detect_dotnet_kegs()` after `detect_dotnet_root()` (~line 72), `build_content()` (~line 85), `main()` (~line 136 onward)
- Also produces (generated, committed in the *dotfiles* repo, not esetup): `~/kernvex/dotfiles/fish/.config/fish/conf.d/esetup-toolchains.fish`

**Interfaces:**
- Consumes: nothing from earlier tasks (detection is by binary on disk, per the script's contract — correct however the keg arrived).
- Produces: `detect_dotnet_kegs()` printing one keg `opt` path per line (e.g. `/opt/homebrew/opt/dotnet@8`); `build_content DOTNET_ROOT GCLOUD_INC DOTNET_KEGS` (third parameter, newline-separated keg paths); a `dotnetN` fish function per keg in the generated file.

- [ ] **Step 1: Add the header row**

After the `gcloud` entry in the header comment (the lines describing `path.fish.inc`), add:

```bash
#   dotnet@N   one `dotnetN` fish function per versioned SDK keg. Keg-only formulae
#              never link into the brew prefix's bin, so PATH cannot reach them;
#              the function is the managed way to invoke one.
```

- [ ] **Step 2: Add `detect_dotnet_kegs()`**

Insert after `detect_dotnet_root()`:

```bash
# Versioned kegs (dotnet@8, …), by binary on disk like everything else here.
# The opt path is printed rather than the Cellar one: it survives version bumps.
detect_dotnet_kegs() {
  local keg
  for keg in "$(brew_prefix)/opt/"dotnet@*; do
    [[ -x "${keg}/bin/dotnet" ]] || continue
    printf '%s\n' "$keg"
  done
  return 0
}
```

(An unmatched glob leaves the literal pattern, which fails the `-x` test — no `nullglob` needed.)

- [ ] **Step 3: Extend `build_content()`**

Change its signature line from:

```bash
  local dotnet_root="$1" gcloud_inc="$2"
```

to:

```bash
  local dotnet_root="$1" gcloud_inc="$2" dotnet_kegs="$3"
```

and append before the function's closing `}` (after the gcloud block):

```bash
  if [[ -n "$dotnet_kegs" ]]; then
    printf '\n%s\n' "# Versioned .NET SDK kegs. Keg-only, deliberately not on PATH — the brew"
    printf '%s\n' "# prefix's \`dotnet\` always wins there, so each gets a function instead."
    local keg name major
    while IFS= read -r keg; do
      [[ -n "$keg" ]] || continue
      name="$(basename "$keg")"
      major="${name#dotnet@}"
      printf '%s\n' "function dotnet${major} --description 'dotnet from the ${name} keg'"
      printf '%s\n' "  ${keg}/bin/dotnet \$argv"
      printf '%s\n' "end"
    done <<<"$dotnet_kegs"
  fi
```

- [ ] **Step 4: Extend `main()`**

Three edits, in order:

Declaration and detection — replace:

```bash
  local dotnet_root="" gcloud_inc=""
  dotnet_root="$(detect_dotnet_root || true)"
  gcloud_inc="$(detect_gcloud_path_inc || true)"
```

with:

```bash
  local dotnet_root="" gcloud_inc="" dotnet_kegs=""
  dotnet_root="$(detect_dotnet_root || true)"
  gcloud_inc="$(detect_gcloud_path_inc || true)"
  dotnet_kegs="$(detect_dotnet_kegs || true)"
```

Logging — after the gcloud `log_info`/`else` block, add:

```bash
  if [[ -n "$dotnet_kegs" ]]; then
    log_info "Found versioned .NET SDK keg(s): $(printf '%s' "$dotnet_kegs" | tr '\n' ' ')"
  else
    log_info "No versioned .NET SDK kegs found; skipping their functions."
  fi
```

Emptiness check and content — replace:

```bash
  if [[ -z "$dotnet_root" && -z "$gcloud_inc" ]]; then
```

with:

```bash
  if [[ -z "$dotnet_root" && -z "$gcloud_inc" && -z "$dotnet_kegs" ]]; then
```

and replace:

```bash
  content="$(build_content "$dotnet_root" "$gcloud_inc")"
```

with:

```bash
  content="$(build_content "$dotnet_root" "$gcloud_inc" "$dotnet_kegs")"
```

- [ ] **Step 5: Dry-run to verify the emission (this machine has dotnet@8)**

Run: `bash -n scripts/apply-toolchain-env.sh && ./scripts/apply-toolchain-env.sh --dry-run`
Expected: `Found versioned .NET SDK keg(s): /opt/homebrew/opt/dotnet@8`, then `[dry-run] would write` output containing the three lines `function dotnet8 --description 'dotnet from the dotnet@8 keg'` / `  /opt/homebrew/opt/dotnet@8/bin/dotnet $argv` / `end`, and the existing `DOTNET_ROOT` line unchanged.

- [ ] **Step 6: Real run, then prove the function works and the run is idempotent**

Run:
```bash
./scripts/apply-toolchain-env.sh
fish -c 'dotnet8 --version'
./scripts/apply-toolchain-env.sh
```
Expected: `Wrote …esetup-toolchains.fish`; then `8.0.1xx`; then `already up to date.`

- [ ] **Step 7: Commit — esetup, then the generated file in the dotfiles repo**

```bash
cd ~/Documents/Projects/setup/esetup
git add scripts/apply-toolchain-env.sh
git commit -m "feat(toolchain-env): dotnetN fish function per versioned SDK keg

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"

cd ~/kernvex/dotfiles
git add fish/.config/fish/conf.d/esetup-toolchains.fish
git commit -m "chore: regenerate esetup-toolchains.fish (dotnet8 keg function)

Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>"
```

---

### Task 4: End-to-end verification against the spec

**Files:**
- No edits. Read-only checks.

**Interfaces:**
- Consumes: everything above.
- Produces: evidence for the completion claim.

- [ ] **Step 1: Syntax pass over every touched file**

Run: `cd ~/Documents/Projects/setup/esetup && bash -n setup.sh && bash -n modules/dotnet.sh && bash -n scripts/apply-toolchain-env.sh && echo SYNTAX-OK`
Expected: `SYNTAX-OK`.

- [ ] **Step 2: Re-run the behavioral harness**

Run: `bash /tmp/dotnet-versioned-harness.sh`
Expected: `ALL PASS`.

- [ ] **Step 3: Spec checklist**

Confirm each spec promise has evidence:
1. Owned `dotnet@8` converges under `--upgrade` — harness case 1.
2. `--upgrade` never introduces — harness case 2.
3. Interactive introduce with gate — harness cases 3, 4, 7.
4. Typo'd/disabled keg → Manual with Reason, not Failed — harness cases 5, 6.
5. `dotnet8` function generated, invocable, retractable-by-regeneration — Task 3 steps 5–6 (retraction is the existing wholesale-regeneration contract; no new code path to test).
6. `DOTNET_ROOT` untouched by kegs — Task 3 step 5 output shows the existing line unchanged.

- [ ] **Step 4: Clean up the throwaway harness**

Run: `rm /tmp/dotnet-versioned-harness.sh`
