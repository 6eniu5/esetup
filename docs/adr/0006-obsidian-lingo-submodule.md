---
status: accepted
---

# Lingo vault as a second generator submodule

The Lingo language-learning vault follows the same submodule-generator pattern as
Habits ([ADR-0005](./0005-obsidian-habit-tracker-submodule.md)):
`kernvex/obsidian-lingo` is a git submodule with an `optional_obsidian_lingo()`
step that scaffolds the vault (templates + `.obsidian` config) into the Obsidian
iCloud container (`OBSIDIAN_LINGO_VAULT`, default `…/Documents/Lingo`).

It differs from Habits in two ways: Lingo's **cards are content, not generated**
(the generator owns only `_Templates/`, `types.json`, and the folder skeleton —
never the cards), and it uses **obsidian-spaced-repetition (FSRS)** instead of
Bases.

## Decision

- **Per-vault repo, config-driven.** `obsidian-lingo` is standalone (mirrors
  Habits), with `lingo.yaml` driving the languages + card-field schema so
  `add-language` is one command. A future programming-language vault **forks** it
  (Concepts = coding ideas, Words = per-language implementations) — a shared
  framework was considered and deferred until that's real (YAGNI).
- **The dotfiles `obsidian` package became multi-vault:** `obsidian/{habits,lingo}/`,
  applied by a per-vault loop in `install` (per-vault `OBSIDIAN_*_VAULT` overrides).

## Consequences

- Two Obsidian vaults now bootstrap from esetup — same shape, independent.
- Adding a third vault = a new (forked) generator repo + submodule, a new
  `obsidian/<name>/` dotfiles subdir + `obsidian_copy` line, and a new
  `optional_*` step.
