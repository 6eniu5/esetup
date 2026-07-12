# esetup

A macOS bootstrap script that brings a fresh machine to a known state: Homebrew packages,
language toolchains, dotfiles, and Claude Code skills. Reruns must be safe.

## Language

### The install surface

**Declared Set**:
The artifacts `setup.sh` promises to put on a machine. Enumerated in the script itself, not
discovered from the machine.
_Avoid_: package list, manifest

**Artifact**:
One member of the Declared Set that carries a version: a brew formula, a brew cask, or Rust.
Not every Artifact yields a binary — fonts and apps do not.
_Avoid_: package, dependency

**Non-Artifact**:
A step in `setup.sh` that changes the machine but has no version to diff: stowing, `chsh`,
applying caveat actions, the Karabiner build, the VoiceInk Source Build. Never part of a Plan.
Under `--upgrade` the idempotent ones run and the destructive ones are suppressed into Manual.

**Source Build**:
A Non-Artifact that clones an upstream GPL repo, compiles it locally, and installs the
resulting app — chosen where the brew cask is paid or license-gated. VoiceInk is the first:
its cask is a paywalled pre-built binary, but the GPL-3.0 source builds free (`make local`,
ad-hoc signed). Carries an upstream version but no Plan; updated by re-running the build
(`git pull`), never `brew upgrade`. Heavy and destructive, so like the Karabiner build it is
suppressed into Manual under `--upgrade`.
_Avoid_: Artifact (no brew receipt, no Version Diff)

### Ownership

Three predicates that the script has historically conflated. They disagree, and the gap between
them is where reruns corrupt a machine.

**Brew-owned**:
Homebrew has a receipt for this Artifact. `brew list --formula X` or `brew list --cask X`.
This, and only this, is what "installed" means when building a Plan.
_Avoid_: installed, present

**Shadowed**:
An Artifact that *is* Brew-owned, but whose binary resolves outside `$(brew --prefix)` — so the
command you run is not the one Homebrew can upgrade. `claude-code` is shadowed by
`~/.local/bin/claude`. Detected after acting, from brew's own artifact list.

**Foreign**:
An Artifact that is *not* Brew-owned, yet something of that name is already on PATH — installing
would create a second copy and let PATH order pick the winner. Detected before acting, by name.
_Avoid_: shadowed (the reverse case), unmanaged

**Unowned App**:
An `/Applications/X.app` bundle exists for a cask that is not Brew-owned. Installing over it
fails; brew cannot upgrade it. The cask flavour of Foreign.

### The plan

**Plan**:
The memoized result of one `brew update && brew outdated --json=v2 --greedy`, consulted to decide
each Artifact's Action. A lookup table, not a schedule — it does not reorder or reschedule the
steps of `setup.sh`, and an Artifact that is never installed is never looked up.

**Action**:
What the Plan decides for one Artifact. Exactly one of `install`, `upgrade`, `skip`, `manual`,
or `failed`.

**Failed**:
An Action that was attempted and errored. Transient, unlike Manual — it makes the run exit
nonzero, because something broke rather than something being knowingly left alone.

**Manual**:
An Action meaning the script will not converge this Artifact, and will name it in the end-of-run
report along with a Reason. The predicate is Shadowed ∪ Foreign ∪ Unowned App ∪ Pinned, plus any
decision `--upgrade` suppressed rather than asked.

**Reason**:
Why an Artifact was classified Manual. Carried through to the report; a Manual entry without a
Reason is a bug.

### Version handling

**Version Diff**:
The fact that an Artifact's installed version differs from its available version. **No code in
this project computes one.** Homebrew computes it inside `brew outdated`; rustup computes its own
inside `rustup check`. We read verdicts, never compare version strings — so ordering, semver, and
strings like `py314_26.5.3-1` never enter the design.
_Avoid_: version comparison, semver check
