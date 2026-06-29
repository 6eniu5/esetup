# Updating the fork from upstream

`scripts/install-claude-skills.sh` automates this on every re-run (when already installed):
it checks out `main`, fetches `upstream`, reports any **new** skills, merges, and pushes.

## Manual equivalent

```bash
git -C skills fetch upstream
git -C skills checkout main          # see detached-HEAD note below
git -C skills merge --no-edit upstream/main   # clean: our work is in its own bucket
git -C skills push origin main                # update the GitHub fork
# Then record the new submodule pointer in esetup so other machines pull the same SHA:
git add skills && git commit -m "chore: bump skills submodule"
```

## Why it never conflicts

Rules A & B (see `architecture.md`) mean upstream and our changes touch **disjoint files** —
upstream owns everything except `skills/6eniu5/`, which is ours alone. The merge is always a
clean fast-forward of their files plus our untouched bucket.

## Detached-HEAD note (why the script does `checkout -B main`)

After `git submodule update --init` on a fresh machine the submodule sits at a **detached HEAD**
on the pinned SHA, with **no local `main` branch**. So `git rev-parse main` / `git checkout main`
would fail. The installer's `ensure_main_branch` first runs
`git checkout -B main origin/main` (after `git fetch origin`) to materialize the branch before
syncing. Do the same if syncing by hand on a new checkout.

## Merge vs rebase

The script uses **merge** (no force-push, safe to automate). A linear history via
`git rebase upstream/main` + `git push --force-with-lease origin main` is a fine *manual*
alternative on a personal fork — but don't automate force-pushes.

## Detecting new upstream skills

```bash
git -C skills diff --name-status main..upstream/main -- skills | awk '$1=="A" && $2 ~ /SKILL\.md$/'
```
This is the canonical "what new skills did Matt add?" check (the script prints it during sync).
