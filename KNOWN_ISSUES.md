# Known Issues

## Homebrew caveats target zsh instead of fish

**Status:** Fixed (in `setup.sh`)  
**Affects:** Was: first run of `setup.sh` before fish was the default shell

### Problem (historical)

`setup.sh` runs in bash, and the login shell was often still zsh when Homebrew
installed formulas. Homebrew then installed shell completions into zsh paths and
printed zsh-oriented caveat text.

### Resolution

1. **Install `fish` first** (immediately after preflight), before other formulas.
2. **`export SHELL="$(command -v fish)"`** so subsequent `brew install` / cask
   steps target fish for completions and caveat wording.
3. **`brew completions link`** is run once after all Homebrew steps (including
   optional Miniconda), with `SHELL` set to fish.
4. **`apply_known_caveat_actions`** remains: it still appends Homebrew fish
   completion paths to `config.fish` when caveat capture detects fish completion
   hints.

---

## Actionable caveats at end of install reference the wrong shell

**Status:** Fixed (same root cause as above)  
**Affects:** Was: first run of `setup.sh` when `$SHELL` still implied zsh

### Problem (historical)

Homebrew tailored “add this to your profile” style instructions to the shell
inferred from the environment, so users saw `.zshrc` / zsh syntax instead of
fish.

### Resolution

Setting **`SHELL` to the fish binary** before the bulk of `brew install` runs
(see previous section) aligns caveat text with fish where Homebrew supports it.
`apply_known_caveat_actions` still covers completion paths; ad-hoc formula text
may still need manual translation for unusual packages.
