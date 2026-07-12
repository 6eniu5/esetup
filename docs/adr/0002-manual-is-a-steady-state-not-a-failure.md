---
status: accepted
---

# Manual is a steady state, not a failure

`--upgrade` is meant to be run unattended. Some Artifacts can be seen but must not be touched:
`claude-code` is Brew-owned yet Shadowed by `~/.local/bin/claude`; Raycast is running right now
and swapping its `.app` out from under it would leave a live process on deleted code. We classify
these **Manual** with a Reason, decline to act, and **still exit 0**. Only an Artifact we tried and
failed to converge is **Failed**, and only Failed makes the run exit nonzero.

The distinction is that Manual is *persistent* and Failed is *transient*. `claude-code` will be
Shadowed next month too. If Manual turned the run red, a monthly `--upgrade` would be red forever
and nobody would read it.

## The Manual predicate

Five cheap booleans, none of which requires parsing a version (see ADR-0001):

- **Shadowed** — Brew-owned, but its binary resolves outside `$(brew --prefix)`. Read from
  `brew ls --verbose <formula>` / cask `artifacts[].binary`, which is complete and needs no
  hand-maintained `gnu-sed`→`gsed` map. Checked **before** converging an Artifact brew already
  owns (`brew ls` works on an installed keg), and **after** installing one it didn't — upgrading a
  copy the user never executes is wasted work, and it would make the report incoherent: an entry
  cannot be both "will not converge" and converged. Two instances existed on the author's machine
  and were resolved by removing the shadowing copy, not by code: `atuin` (a stale self-managed
  `~/.atuin/bin/atuin` 18.13.3 sourced by the bash/zsh rc files — retired so brew's 18.16.1 wins)
  and `claude-code` (the brew cask dropped for the native, self-updating install — see ADR-0003).
  That is what the steady-state report is *for*: a Shadowed entry is a standing instruction to pick
  one copy.
- **Foreign** — not Brew-owned, yet something of that name is on PATH; installing would create a
  second copy and let PATH order pick the winner. Detected *before* acting, by name. Brew cannot
  help here: for an uninstalled formula, `brew ls` errors and the formula JSON has no binary key.
  The by-name pre-check covers every formula where a Foreign copy is realistic (nobody has a stray
  `gnu-sed` on PATH); the post-check catches the rest, one install too late, and reports it.
- **Unowned App** — `/Applications/X.app` exists for a cask brew doesn't own. The cask flavour of
  Foreign, and a pre-emptive catch for the "already an App at '…'" install failure.
- **Running app** — a cask with an `.app` artifact whose process is live. Neither `raycast` nor
  `orbstack` declares an `uninstall`/`quit` stanza, so brew would replace the bundle underneath
  the running process. We decline; the next run after a restart picks it up.
- **Pinned** — `.pinned` in the outdated JSON. None today.

Plus any decision `--upgrade` suppressed rather than asked (below).

## Consequences

- Exit codes: `0` converged (Manual entries may be printed), `1` one or more Artifacts Failed,
  `2` the run could not start (no brew, `brew update` failed, no network).
- A single `brew upgrade` failure records **Failed** and continues to the next Artifact.
  Convergence is per-Artifact independent. Today these are swallowed by `|| log_warn` and the run
  stays green — that is the bug this replaces.
- `--upgrade` is non-interactive. Idempotent Non-Artifacts run (stow, caveat actions, the skills
  installer); destructive ones are suppressed (`chsh`, the Karabiner `yarn build` +
  `launchctl kickstart`). **Every suppressed decision emits a Manual entry with a Reason** — not a
  `log_warn`. Otherwise a cron run quietly does half its job: `stow_one_package` prompts when a
  target exists and isn't a symlink, and with no stdin the `read` fails, `ans` is empty, the
  default `n` wins, and your fish config silently stops being stowed.
- We keep `brew outdated --greedy`, which surfaces `auto_updates: true` casks. Combined with the
  running-app rule this degrades correctly: stopped apps (OrbStack, Karabiner) upgrade; running
  ones (Raycast, Claude) report. We decline to upgrade precisely the set of apps that update
  themselves.
- Foreign/Shadowed detection runs in **all** modes, not just `--upgrade`. A Foreign `bun` is just
  as dangerous on a default `prompt` run.

## Watch out

**`command -v` is not the oracle.** `ensure_homebrew` runs `eval "$(brew shellenv)"`, which
prepends `$(brew --prefix)/bin` to `PATH`. After that, `command -v claude` answers "which copy does
*this script* see", not "which copy does the *user* run" — so the script masks the very shadow it
is looking for. Shadowed and Foreign resolve against `ESETUP_ORIGINAL_PATH`, captured at line 1
before anything mutates it, walked in order so the first hit is what the user actually invokes.
This was caught by a test, not by review.

**A submodule's `.git` is a FILE, not a directory.** `[[ -d <path>/.git ]]` is false for every
healthy submodule, so the old `init_dotfiles_git` ran `rm -rf nvim/.config/nvim` on *every* run,
watched `git submodule add` fail into a `log_warn`, and was saved only because a later
`git submodule update --init` restored the tree. Uncommitted work was destroyed silently and the
run exited 0. Test `-e`; move aside, never `rm -rf`; and record Failed, not a warning.

`rustup check` exits **100** when an update is available. Under `set -euo pipefail` an
unguarded `out="$(rustup check)"` aborts the script on exactly the machines with something to
upgrade. Likewise `local PLAN="$(brew outdated …)"` always exits 0 — the status is `local`'s, not
the command's. The Plan builder must use a bare assignment or an explicit `if ! PLAN="$(…)"`.
