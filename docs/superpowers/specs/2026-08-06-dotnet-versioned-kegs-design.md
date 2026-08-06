# Versioned .NET SDK kegs (`dotnet@N`)

## Why

Work repos pin majors older than the machine's primary SDK (ClientPortal.Api and
the modern EnterpriseServices projects target net8.0; the `dotnet` formula is
already on 10). Building works from any newer SDK, but *running* on the pinned
major needs its runtime — `DOTNET_ROLL_FORWARD=LatestMajor` works, at the cost of
testing on a runtime production will never use. Homebrew publishes versioned
kegs (`dotnet@8`, `dotnet@9`, …) that provide the real runtime, keg-only, so they
never touch `$(brew --prefix)/bin/dotnet` and cannot collide with either flavour
of the primary SDK. Today they are invisible to esetup: a hand-installed
`dotnet@8` is unmanaged, unconverged, and unnamed in any report.

## Declaration

`ESETUP_DOTNET_VERSIONS` — space-separated majors (`"8"`, `"8 9"`), sibling to
`ESETUP_DOTNET_FLAVOR` in `modules/dotnet.sh`. Each major `N` maps to formula
`dotnet@N`. Unset means "ask on interactive runs", the flavour variable's
contract.

## Module behavior

New `optional_dotnet_versioned()` in `modules/dotnet.sh`, called from `main()`
on its own line immediately after `optional_dotnet`, with the same
no-`record_failed`-wrapper comment (every path goes through
`brew_install_formula`, which records its own Failed entries). It runs
regardless of the flavour situation, including on a machine stuck in the
both-flavours collision — kegs are orthogonal to the shared symlink.

Two phases:

1. **Converge owned** (every run, including `--upgrade`): every `dotnet@*` in
   `OWNED_FORMULAE` goes through `brew_install_formula` — Plan lookup, upgrade,
   pinned→Manual, shadow checks, all existing machinery.
2. **Introduce wanted** (interactive runs only): wanted =
   `ESETUP_DOTNET_VERSIONS`; if unset, one free-text prompt for space-separated
   majors (empty skips). One `prompt_yes_no` gate naming the kegs about to be
   added, then `brew_install_formula` each. Under `NONINTERACTIVE` this phase is
   skipped entirely: `--upgrade` never introduces, even with the variable set.

A wanted formula brew does not know (typo, or a disabled keg such as
`dotnet@6`) is recorded **Manual** with a Reason via a `brew info --formula`
pre-check — user error is knowingly left alone, not Failed.

No ownership-predicate changes needed, verified against the live install:
`is_foreign_formula "dotnet@8"` probes for a binary literally named `dotnet@8`
(never exists — harmless no), and `check_shadowed_formula` resolves the keg's
`dotnet` to the brew prefix copy, inside the prefix — no false Manual.

## Shell handle

`scripts/apply-toolchain-env.sh` gains one detection alongside
`detect_dotnet_root`: glob `$(brew --prefix)/opt/dotnet@*/bin/dotnet`, keeping
only links that resolve into a Cellar directory bearing their own name. The
filter exists because brew leaves opt symlinks for *aliases* too — with the
primary formula on 10, `opt/dotnet@10` (and a stale `opt/dotnet@9`) resolve to
`Cellar/dotnet`, and a `dotnet9` function running SDK 10 would be a lie. For
each real keg, the generated `esetup-toolchains.fish` (Dotfiles Repo fish Stow
Package, symlinked live) gains:

```fish
# Versioned .NET SDK kegs. Keg-only, deliberately not on PATH — the brew
# prefix's `dotnet` always wins there, so each gets a function instead.
function dotnet8 --description 'dotnet from the dotnet@8 keg'
    /opt/homebrew/opt/dotnet@8/bin/dotnet $argv
end
```

The path is written from the detected glob hit, not hardcoded. Everything else
is inherited from the script's existing contract: detection by binary-on-disk
(correct however the keg arrived), wholesale regeneration (uninstall the keg,
re-run, function retracted), `--dry-run`, standalone re-runnable. `DOTNET_ROOT`
stays pointed at the primary flavour only; kegs never claim it.

## Docs

Header comment in `modules/dotnet.sh` grows the reasoning above (pinned majors,
runtime fidelity vs roll-forward, keg-only means no collision, the
`ESETUP_DOTNET_VERSIONS` contract, invocation via `dotnetN`). The toolchain
table in apply-toolchain-env's header gains a row for the keg functions. No ADR.

## Error handling

- Unknown/disabled formula → Manual with Reason (pre-checked).
- Real formula, failed install/upgrade → Failed, nonzero exit — unchanged.
- No keg on disk → apply-toolchain-env contributes nothing, as with every other
  absent toolchain.

## Verification

- `bash -n` on `setup.sh`, `modules/dotnet.sh`, `scripts/apply-toolchain-env.sh`.
- `apply-toolchain-env.sh --dry-run`, then real run; `dotnet8 --version` prints
  8.0.x in a fresh fish shell.
- `optional_dotnet_versioned` exercised with `NONINTERACTIVE=1` (converge-only;
  the machine's `dotnet@8` is current, so expect "Up to date" and no new
  Manual/Failed entries).
