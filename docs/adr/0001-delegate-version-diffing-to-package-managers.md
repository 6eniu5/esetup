---
status: accepted
---

# Delegate version diffing to the package managers

`--upgrade` needs to know which Artifacts are out of date. The obvious build is a table of
`(latest_cmd, installed_cmd)` per Artifact, collected into two lists and compared. We rejected
that: **no code in this project compares two version strings.** `brew outdated --json=v2 --greedy`
already returns installed and available side by side for every formula and cask in one process,
and `rustup check` already prints its own verdict. We read those verdicts.

## Considered Options

- **Own two-list machinery.** ~64 subprocesses (`brew info` + `brew list --versions` per package),
  and we would have had to teach ourselves to order strings like
  `1.15962.1,1e236d9fa9efd21a5a0a66a7b70c028f48848604` and `py314_26.5.3-1`. Rejected.
- **Delegate.** Three commands total: `brew update`, `brew list --formula`/`--cask`,
  `brew outdated --json=v2 --greedy`. Accepted.

## Consequences

- We never need version *ordering*, only inequality — the machine is never downgraded, so
  "differs" is a sufficient decision input. This is what makes the feature deterministic.
- Homebrew's JSON schema is now load-bearing. If `brew outdated --json=v2` changes shape, the Plan
  breaks. Accepted: it is a versioned interface (`v2`), which is why we pin to it explicitly.
- `--upgrade` cannot run offline. `brew update` is required to build the Plan, and there is
  **no cached-metadata fallback**: a Plan built from stale metadata looks authoritative — real
  versions, real diffs — while silently comparing against yesterday's internet. We abort (exit 2)
  rather than produce one.
- Rust is a special case, not an instance of a general "Adapter" interface. `rustup check` reports
  a decision, not a version pair, and covers two things at once (the toolchain and rustup itself).
  An interface with one implementation that doesn't fit it is worse than three special cases; when
  `uv`/`pyenv` arrive, the right shape will be visible. SDKMAN is permanently Manual — it is a
  shell function, not a binary, its output is prose, and it currently manages zero candidates.
- `brew update` is slow and online, so the Plan is split: **ownership** (`brew list`, 0.05s,
  offline) is built on every run; **diffs** (`brew update` + `brew outdated`) only under
  `--upgrade`. As a side effect this deletes ~12s of per-package `brew list <name>` probing
  (0.373s each) from every run — the bare dump is 16× faster than the named form.
- The Plan is a memoized lookup table, not a schedule. It does not reorder `setup.sh`, which has
  real ordering constraints (fish must install before other formulae so `$SHELL` drives Homebrew's
  completion paths) and a Declared Set that is only known once interactive prompts are answered.
- The Plan must be built *after* `trust_brew_taps`, or third-party tap packages (e.g. `bun` from
  `oven-sh/bun`) may be missing from the diff and silently classified `skip`.
