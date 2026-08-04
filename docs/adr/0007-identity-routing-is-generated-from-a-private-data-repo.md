---
status: accepted
---

# Identity routing is generated from a private data repo

A machine used for more than one client has to answer "who am I here?" for every tool
independently: which SSH key authenticates, which name lands in a commit, and which account
each CLI (`gh`, `gcloud`, `az`, `aws`) acts as. Git answers the first two natively with
`includeIf "gitdir:"`, keyed on the repo's path. **The CLIs have no folder awareness at all.**
Each keeps one active account in its own config, switched globally by a command you have to
remember to run.

Bridging that gap by hand meant one identity was described in five places — the `includeIf`,
a per-identity `.inc`, a fish hook, a zsh hook, and a config directory per tool — with nothing
checking them against each other. The drift is invisible. A CLI holding the wrong account does
not report an auth error; GitHub answers queries about private repos you cannot see with
*"Could not resolve to a Repository"*, which reads as a wrong URL. The work simply appears not
to exist.

## Decision

**One data file per identity; every routed file is generated from it. The data lives in a
private repo, cloned conditionally.**

- **The folder is the only switch.** An identity owns a directory; everything under it routes
  to that identity, and everything else is personal. Not the shell you used, not the account
  you last switched to, not a flag you remembered.
- **Per-identity config directories, not profile switching.** Each tool is pointed at its own
  config directory via an environment variable set by a `cd` hook. Two identities' credential
  stores then cannot shadow each other, and there is no global mode to leave flipped.
- **A tool registry, not a hardcoded pair.** One row per tool — its environment assignments, a
  verify command, a login command. Adding a tool to an identity is one word; adding a new tool
  is one row.
- **Personal is declared but generates nothing.** It must remain the unrouted default, or the
  folder stops being the only switch. It is written down so the checker knows what correct
  looks like *outside* every work folder — the half that had never been asserted.
- **The private repo is cloned by `scripts/clone-private-repos.sh`, not vendored as a
  submodule.** Same reasoning as the repos already in that table: this repo is public, a
  private submodule advertises its URL in a public `.gitmodules` and breaks
  `clone --recursive` for everyone without access. The pinned SHA a submodule buys is actively
  wrong here — stale routing data on a restored machine is worse than none.
- **`setup.sh` runs `apply` after the dotfiles step**, as a Non-Artifact. It depends on stow
  having placed `~/.gitconfig` with its generic `[include]` line. Restoring keys is reported as
  **Manual**: it needs a passphrase per identity and a browser login per tool, so it can never
  converge unattended.

## Consequences

**Generated files are output.** Editing one by hand is silently undone by the next `apply`.
Each carries a `DO NOT EDIT` header, and the first commit of the private repo is a byte-for-byte
capture of the pre-generator originals, so a bad template is always one `git show` away from the
version that worked.

**A checker is now part of the design, not an extra.** Because every failure here is silent, a
generator without verification would only move the problem. The check asserts both directions —
work folders resolve to their identity, *and* everything outside them resolves to personal —
and reports repos that pin an identity by hand, which is invisible to the model. It emits JSON
and exits nonzero on drift, so unattended callers can branch on it.

**The public repos never learn who the clients are.** The private repo's *name* is visible in
the clone table, so it is deliberately generic. Everything client-specific — folders, emails,
accounts — exists only in the private repo and on disk. This document uses no real values for
the same reason.

**A machine without access still works.** The clone is skipped, the step is skipped, and the
run succeeds with one feature missing. That is the correct outcome for a public bootstrap repo.

## Alternatives rejected

**Keep hand-written files and back them up.** Preserves every drift and sync problem; "add an
identity" stays a five-file edit that nothing validates.

**Have both shells read a shared map at runtime.** Removes the generation step for hooks, but
puts a parser in the interactive shell's `cd` path, and git still needs generated config files —
so it buys one mechanism and adds a second.

**One private vault repo per identity** (the previous convention). The routing files an identity
needs are global and cannot live in a per-identity repo, so the identity ends up split across
two places for no gain: private is private, and each vault keeps its own passphrase either way.
