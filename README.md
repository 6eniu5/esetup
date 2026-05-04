# esetup

Interactive macOS bootstrap: Homebrew, CLI tools, fnm/bun, optional Miniconda and SDKMAN!, optional Karabiner Elements (via the `karabiner-manager` submodule), and GNU Stow dotfiles under `~/6eniu5/dotfiles` by default (override with env `TARGET_DOTFILES`).

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

## Karabiner Elements and Raycast

The repo includes a **git submodule** at [`karabiner-manager`](./karabiner-manager) ([`6eniu5/karabiner-manager`](https://github.com/6eniu5/karabiner-manager)): TypeScript (`rules.ts`) generates `karabiner.json` and writes it to `~/.config/karabiner/karabiner.json` (override with env `KARABINER_CONFIG_PATH` when running `yarn build`).

**Clone with submodules** (or initialize later):

```bash
git clone --recurse-submodules https://github.com/6eniu5/esetup.git
# or, from an existing clone:
git submodule update --init --recursive
```

**Verify the submodule remote** (requires [GitHub CLI](https://cli.github.com/)):

```bash
gh repo view 6eniu5/karabiner-manager
git submodule status
```

During `./esetup/setup.sh`, after the fnm Node step, you can opt in to install **Karabiner Elements**, **Raycast**, and **Rectangle** (used by window-management shortcuts), back up any existing `~/.config/karabiner/karabiner.json`, run `yarn install` / `yarn build` in `karabiner-manager`, and kickstart the Karabiner user daemon so the new JSON loads.

Rebuild by hand after editing rules:

```bash
cd karabiner-manager && yarn install && yarn build
launchctl kickstart -k "gui/$(id -u)/org.pqrs.karabiner.karabiner_console_user_server"
```

**Raycast follow-up:** many Hyper-key bindings open `raycast://…` deep links (built-in Raycast commands plus third-party extensions such as Toothpick, Silent Mention, and custom script commands). Until those extensions or scripts are installed, some shortcuts may do nothing or show an error in Raycast. A future pass can document required extensions or trim `rules.ts` to match what you actually install.

## Requirements

- macOS
- Network for Homebrew and git submodules (SSH keys for GitHub)

## Dotfiles layout

Stow packages live under `~/6eniu5/dotfiles/` (default): `fish`, `starship`, `wezterm`, `tmux`, `tmux-sessionizer-config`, `bin`, `nvim`.
