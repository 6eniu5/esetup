# Troubleshooting

## Dangling symlinks in `~/.claude/skills`

Cause: the submodule wasn't initialized, so symlink targets don't exist.
Fix:
```bash
git -C <esetup> submodule update --init --recursive -- skills
bash scripts/install-claude-skills.sh
```

## `git rev-parse main` / `checkout main` fails in the submodule

The submodule is at a detached HEAD with no local `main` (fresh `--init`). Run:
```bash
git -C skills fetch origin
git -C skills checkout -B main origin/main
```
The installer's `ensure_main_branch` does this automatically — see `updating-the-fork.md`.

## A skill didn't get linked

- It must live at `skills/<bucket>/<name>/SKILL.md` and the bucket must be in `ALLOWED_BUCKETS`
  (default: `engineering productivity misc 6eniu5`).
- If `~/.claude/skills/<name>` already exists as a **real file/dir** (not a symlink), the
  installer skips it with a `! skip` message — remove it, then re-run.

## Name collision

`~/.claude/skills/` is flat. Two skills with the same folder name across buckets clash — the
last `ln -sfn` wins. Rename your personal skill folder to something unique.

## `gh` not logged in (fork step)

```bash
gh auth status   # if not logged in:
gh auth login
```

## Accidentally edited an upstream file (broke Rule B)

The pristine check should print nothing:
```bash
git -C skills diff --stat upstream/main -- . ':(exclude)skills/6eniu5'
```
If it lists files, you edited upstream-tracked paths — revert them (`git -C skills checkout --
<file>`), keeping changes only under `skills/6eniu5/`.

## macOS / BSD vs GNU

The installer is BSD-compatible (no `readlink -f`, no `find -lname`, no GNU-only flags). If you
extend it, keep it BSD-safe — macOS ships BSD coreutils, not GNU. `ln -sfn` and `find -maxdepth`
are fine.
