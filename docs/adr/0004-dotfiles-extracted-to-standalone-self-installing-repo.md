---
status: accepted
---

# Dotfiles extracted to a standalone, self-installing repo

esetup was doing two jobs at once: it was the **bootstrap installer** *and* the **dotfiles
source** (`esetup/dotfiles/`), joined by a one-way `rsync` into `~/6eniu5/dotfiles` — a throwaway
`git init`'d only to host the `nvim` and `tmux-sessionizer` submodules — which was then stowed into
`$HOME`. That indirection produced every dotfiles problem we hit this session: edits made in the
deploy target never flowed back to source (drift — the WezTerm Copy Mode change had to be
hand-ported), the deploy target was an **orphan** (no remote, 0 commits, unrelated to the real
GitHub repo), and stow **folded** `~/.local/bin` into the throwaway so the Claude installer wrote
into it.

## Decision

Dotfiles become their own repo, **`6eniu5/dotfiles`**, and esetup becomes purely the installer.

- **Reclaim the name.** The old Linux dotfiles were renamed `6eniu5/dotfiles` → `6eniu5/dotfiles-example`
  (history preserved, GitHub redirects), freeing `6eniu5/dotfiles` for the current macOS setup.
- **Self-installing.** The repo carries its own `install` script (`stow --no-folding` per package),
  so `git clone … && ./install` works on any machine *without esetup*.
- **All personal config, one home.** Stow packages (`fish`, `starship`, `wezterm`, `tmux`,
  `tmux-sessionizer-config`, `bin`, plus `atuin`, `git`, `htop`) **plus** non-stowed artifact areas
  (`keyboard/`, `raycast/`) the installer applies, **plus** the `nvim` (kickstart.nvim) and
  `tmux-sessionizer` submodules.
- **esetup orchestrates.** It clones/pulls `6eniu5/dotfiles`, runs the repo's `install`, and applies
  the non-stowed artifacts. `sync_dotfiles_to_home` (rsync), `init_dotfiles_git`, and
  `sync-dotfiles.sh` are removed.

## Considered Options

- **Fold dotfiles into esetup, stow from `esetup/dotfiles`.** One repo, no rsync — but `$HOME`
  symlinks would point into a deep project checkout, and the dotfiles couldn't be deployed without
  dragging the whole installer along. Rejected: breaks portability.
- **Keep the three-stage rsync flow.** Rejected: it is the source of the drift, orphan, and folding
  bugs above.

## Consequences

- **Single source of truth.** `esetup/dotfiles` (proven byte-identical to the live `~/.config`) moves
  out; there is one place a config lives.
- **Portable.** A fresh machine clones the repo and runs `./install`; esetup is only needed for the
  wider bootstrap (Homebrew, runtimes, secrets).
- **`$HOME` symlinks point into `~/6eniu5/dotfiles`, now a real clone** with a remote and history —
  not a throwaway.
- **Landmine to defuse:** `~/.dotfiles`… no — the local clone `setup/.dotfiles` was deleted, but any
  clone whose `origin` is `git@github.com:6eniu5/dotfiles.git` now re-points at the NEW repo once it
  exists (GitHub drops the rename-redirect). Such clones must be re-pointed to `dotfiles-example.git`.
- **Salvage merged in** (verified against the live config, no feature lost): eza listing aliases
  (`la/ll/lla/lll/llll`), the Vazir (Persian) + Cascadia Code Light WezTerm font fallback, and newly
  versioned `~/.config/atuin`, `~/.gitconfig`, `~/.config/htop`. The starship prompt stays the
  simpler current one (the loose `aws/python/conda` variant is dropped). The tree-sitter theme from
  the old `f412h4d/.dotfiles` is skipped (stale Linux parser path).
- **`bin` is stowed `--no-folding`** so `~/.local/bin` is a real directory the Claude installer can
  write into without polluting the repo (see docs/adr/0002 watch-out and the folding fix).
- **karabiner stays split:** the generator (`karabiner-manager`) remains esetup tooling; its output
  is not tracked.
- esetup keeps `skills` and `karabiner-manager` as its submodules; `nvim`/`tmux-sessionizer` were
  never esetup submodules, so they attach cleanly to the dotfiles repo with nothing to move out.
