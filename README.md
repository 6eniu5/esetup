# esetup

Interactive macOS bootstrap: Homebrew, CLI tools, fnm/bun, optional Miniconda and SDKMAN!, optional Karabiner Elements (via the `karabiner-manager` submodule), and the standalone self-installing dotfiles repo cloned to `~/6eniu5/dotfiles` by default (override with env `TARGET_DOTFILES`).

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
- **`~/6eniu5/dotfiles`** (or `TARGET_DOTFILES`) — warns if the path exists but is not the dotfiles git clone (setup leaves it alone).
- **Two Homebrew installs** — warns if both `/opt/homebrew` and `/usr/local` have `brew`.

Dotfiles are a **standalone repo** ([`6eniu5/dotfiles`](https://github.com/6eniu5/dotfiles)); esetup clones it to `~/6eniu5/dotfiles` (default; override with `TARGET_DOTFILES`), runs its self-installer (`./install`, `stow --no-folding`), and applies the non-stowed artifact areas (`raycast/`, `keyboard/`). See [docs/adr/0004](./docs/adr/0004-dotfiles-extracted-to-standalone-self-installing-repo.md).

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

## Obsidian Habits

The repo includes a **git submodule** at [`obsidian-habit-tracker`](./obsidian-habit-tracker) ([`6eniu5/obsidian-habit-tracker`](https://github.com/6eniu5/obsidian-habit-tracker)): a generator that turns `habits.md` into a full Obsidian **Habits** vault (daily-note template, Bases views, heatmaps, streak dashboard). Same pattern as `karabiner-manager`. See [docs/adr/0005](./docs/adr/0005-obsidian-habit-tracker-submodule.md).

During `./esetup/setup.sh`, after the Karabiner step, you can opt in to
`optional_obsidian_habit_tracker`: it initializes the submodule, installs the
**Obsidian** cask, runs `bun install && bun run sync`, and deploys the vault into
the Obsidian iCloud container (override with `OBSIDIAN_HABITS_VAULT`), then copies
in the `.obsidian` config + pinned plugins from the dotfiles `obsidian` package.

**Obsidian ≥ 1.12.4 required** on Mac *and* iPhone — Bases (the dashboard engine)
does not exist before then. Rebuild/redeploy by hand after editing habits:

```bash
cd obsidian-habit-tracker && bun run add-habit   # or: edit habits.md && bun run sync && bun run deploy --apply
```

## Obsidian Lingo

A second generator submodule at [`obsidian-lingo`](./obsidian-lingo) ([`6eniu5/obsidian-lingo`](https://github.com/6eniu5/obsidian-lingo)): a config-driven generator for the **Lingo** language-learning vault — language-agnostic Concepts + per-language flashcards reviewed with obsidian-spaced-repetition (FSRS). Same submodule pattern as `obsidian-habit-tracker`; adding a language is one command (`bun run add-language Spanish`). See [docs/adr/0006](./docs/adr/0006-obsidian-lingo-submodule.md).

During `./esetup/setup.sh`, `optional_obsidian_lingo` (after the Habits step)
inits the submodule, runs `bun install && bun run sync`, deploys the scaffold
(templates + `.obsidian/types.json`) into the iCloud container
(`OBSIDIAN_LINGO_VAULT`), and copies the `.obsidian` config + spaced-repetition
plugin from the dotfiles `obsidian/lingo` package. Your cards are content and sync
via iCloud; the generator never touches them.

## Requirements

- macOS
- Network for Homebrew and git submodules (SSH keys for GitHub)

## Dotfiles

Dotfiles live in their own self-installing repo, [`6eniu5/dotfiles`](https://github.com/6eniu5/dotfiles),
cloned to `~/6eniu5/dotfiles`. Stow packages (`fish`, `starship`, `wezterm`, `tmux`,
`tmux-sessionizer-config`, `bin`, `atuin`, `git`, `htop`, `nvim`) plus the `nvim`/`tmux-sessionizer`
submodules and the `keyboard/`/`raycast/` artifact areas. esetup just clones and runs its `./install`;
the repo also deploys standalone (`git clone … && ./install`). See [docs/adr/0004](./docs/adr/0004-dotfiles-extracted-to-standalone-self-installing-repo.md).

## Go

`setup.sh` installs `go` and `tree-sitter-cli` via Homebrew; fish adds `~/go/bin` to PATH.
In Neovim, Mason auto-installs `gopls` and `goimports` on first `.go` file; format-on-save uses goimports + gofmt.

## Rust

`setup.sh` installs the toolchain via the **official rustup installer** (`run_rustup_default_toolchain`), not Homebrew — see lesson below. fish already has `~/.cargo/bin` on PATH and sources `~/.cargo/env.fish`, so no shell changes are needed. `rustfmt` + `clippy` ship with the stable profile. In Neovim, Mason auto-installs `rust_analyzer` on first `.rs` file; format-on-save uses `rustfmt`.

### Lessons learned

- Use the **official rustup installer** (`curl https://sh.rustup.rs | sh`), not `brew install rustup`. The Homebrew formula is keg-only and keeps its proxies in the keg — it leaves `~/.cargo/bin` **empty**, so nothing lands on the PATH the fish config expects. The official installer populates `~/.cargo/bin` and writes `~/.cargo/env.fish` (the exact layout config.fish was already wired for).

## Go lessons learned

- The CLI is the Homebrew formula **`tree-sitter-cli`**, not `tree-sitter` (that one is library-only, no binary). nvim-treesitter's `main` branch needs it to compile parsers, else builds fail with `ENOENT: 'tree-sitter'`.
- nvim-treesitter is pinned to `branch = 'main'`. Use its API (`require('nvim-treesitter').install(parsers)`), **never** `require('nvim-treesitter.configs').setup{}` — that module exists only on the old `master` branch and errors on `main` (`attempt to call field 'install' (a nil value)` shows the reverse: a stale `master` checkout under a `main` spec). Fix a stale checkout: `cd ~/.local/share/nvim/lazy/nvim-treesitter && git fetch origin main && git checkout main && git reset --hard origin/main`.
- The nvim config is a submodule of `6eniu5/kickstart.nvim` (default branch `master`); push there for new machines. It is now a submodule of the standalone [`6eniu5/dotfiles`](https://github.com/6eniu5/dotfiles) repo — commit dotfiles changes there and push (it has a remote), unlike the old local-only stow target.
