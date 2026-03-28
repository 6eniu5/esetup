# esetup

Interactive macOS bootstrap: Homebrew, CLI tools, fnm/bun, optional Miniconda and SDKMAN!, and GNU Stow dotfiles under `~/6eniu5/dotfiles` by default (override with env `TARGET_DOTFILES`).

## Usage

From the repo root:

```bash
./esetup/setup.sh
```

Non-interactive / skip conflict checks (CI or advanced):

```bash
./esetup/setup.sh --skip-preflight
```

### Preflight (conflicts)

Before installing casks, the script checks for common issues:

- **Docker Desktop vs OrbStack** — both provide a Docker engine/CLI; you get a menu to skip OrbStack, install anyway, or abort.
- **Both stacks installed** — warns if Docker.app and OrbStack are present.
- **Rancher Desktop / Colima** — warns about overlapping container tooling.
- **`docker info` fails** — warns if the CLI exists but the daemon/context is broken.
- **`~/6eniu5/dotfiles`** (or `TARGET_DOTFILES`) — warns if the directory exists with files but is not a git repo (rsync merge).
- **Two Homebrew installs** — warns if both `/opt/homebrew` and `/usr/local` have `brew`.

The script syncs `esetup/dotfiles/` to `~/6eniu5/dotfiles` (default), initializes git, adds submodules (`6eniu5/kickstart.nvim`, `6eniu5/tmux-sessionizer`), links `bin/.local/bin/tmux-sessionizer` into the submodule, and optionally runs `stow`.

## Requirements

- macOS
- Network for Homebrew and git submodules (SSH keys for GitHub)

## Dotfiles layout

Stow packages live under `~/6eniu5/dotfiles/` (default): `fish`, `starship`, `wezterm`, `tmux`, `tmux-sessionizer-config`, `bin`, `nvim`.
