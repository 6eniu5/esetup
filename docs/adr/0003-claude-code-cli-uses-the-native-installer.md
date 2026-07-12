---
status: accepted
---

# Claude Code CLI uses the native installer, not the brew cask

On macOS, `install_claude` installs the Claude desktop app as a cask (`claude`) but installs the
**CLI** via the official native installer (`https://claude.ai/install.sh`, `install_claude_code_native`),
not the `claude-code` cask. ADR-0001's original note — "kept brew-managed so Claude Code defers
self-updates to `brew upgrade`" — described intent that reality contradicted.

## Why the reversal

The native installer self-updates into `~/.local/share/claude/versions/<v>` and points
`~/.local/bin/claude` at the newest. On the author's machine five versions had accumulated
(2.1.201–2.1.207) while the brew cask sat at 2.1.197. So two copies existed with different
versions, and *which one ran depended on PATH order* — the setup.sh launch shell put
`~/.local/bin` first (native won, 2.1.207), while the interactive fish shell put
`/opt/homebrew/bin` first (brew won, 2.1.197). The shadow detector flagged `claude-code` on every
run, correctly: it is genuinely nondeterministic which binary you execute.

Forcing brew to win would mean deleting the native copy *and* defeating Claude Code's own updater,
which reinstates it — empirically the losing side. One self-updating copy (native) is the only
stable end state.

## Consequences

- `--upgrade` no longer manages the Claude Code CLI; it updates itself. This is a deliberate hole
  in the "converge everything" contract, accepted because the tool converges itself better than we
  can.
- The desktop `claude` cask is untouched — it is a separate artifact (the GUI app) and auto-updates.
- On a fresh macOS machine the CLI now arrives via curl | bash rather than brew. Same path Linux
  and WSL already used, so `install_claude_code_native` is no longer a non-macOS-only branch.
- `brew uninstall --cask claude-code` was run once by hand to retire the existing cask; setup.sh no
  longer reinstalls it.
