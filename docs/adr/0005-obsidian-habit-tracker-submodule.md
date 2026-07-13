---
status: accepted
---

# Obsidian habit tracker as a submodule generator

The **Habits** Obsidian vault is built by a generator (`habits.md` → daily
template, Bases file, dashboards, heatmaps) that will change over time and wants
its own git history. Rather than fold that code into esetup or the dotfiles repo,
it lives in its own repo, **`6eniu5/obsidian-habit-tracker`**, added here as a
git **submodule** — the same shape as `karabiner-manager` (a generator that emits
config to a target).

## Decision

- **Submodule + opt-in step.** `optional_obsidian_habit_tracker()` mirrors
  `optional_karabiner_manager()`: it inits the submodule, installs the **Obsidian**
  cask (Bases needs ≥ 1.12.4), runs `bun install && bun run sync`, and deploys the
  generated files into the Obsidian iCloud container
  (`~/Library/Mobile Documents/iCloud~md~obsidian/Documents/Habits`, override with
  `OBSIDIAN_HABITS_VAULT`). Non-interactive runs record it Manual (it writes into
  iCloud).
- **Config split.** esetup owns only the `obsidian` cask + this step. The vault's
  `.obsidian` config and pinned community-plugin binaries (Dataview, Heatmap
  Tracker, Charts for Bases) live in the **dotfiles `obsidian` package**
  (copy-on-install, not stowed — the vault is in iCloud and Obsidian rewrites its
  own JSON). The generator owns `.obsidian/types.json`; the deploy never touches
  `Daily/` notes. This keeps esetup config-free (ADR-0004).
- **Ordering.** `setup_dotfiles` runs before the vault exists, so its `.obsidian`
  copy is skipped; this step rsyncs that config in after deploy creates the vault.

## Consequences

- Editing habits is a `bun run add-habit` (or an edit to `habits.md`) in the
  submodule, which regenerates + deploys + commits + pushes on its own remote.
- The daily *notes* are data and stay in iCloud only, never in any repo.
