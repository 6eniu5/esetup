#!/usr/bin/env bash
# install-job-skills.sh — clone (if reachable) and link kernvex/job-skills, whose skills
# SHADOW their upstream namesakes in ~/.claude/skills.
#
# A conditional clone rather than a submodule, because this repo is PUBLIC and job-skills is
# private: a private submodule makes `git clone --recursive` fail for everyone but the owner,
# on a repo published so others can use it. The submodule's pinned SHA buys little here — a
# skills repo is always wanted at HEAD.
#
# Absent or unreachable, this exits 0 silently. A machine without access to the private repo
# is a machine that keeps the upstream skills and works fine.
#
# Ordering is the whole mechanism: ~/.claude/skills is flat and `ln -sfn` overwrites
# unconditionally, so whoever links last wins. install-claude-skills.sh calls this script at
# its end for exactly that reason — so the documented way to re-link skills cannot leave the
# shadows reverted.
set -euo pipefail

MANAGER_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
JOB_SKILLS="${MANAGER_REPO}/job-skills"

bash "${MANAGER_REPO}/scripts/clone-private-repos.sh"

if [ ! -d "${JOB_SKILLS}/.git" ]; then
  echo "  (job-skills unavailable — upstream skills remain in place)"
  exit 0
fi

bash "${JOB_SKILLS}/scripts/link-skills.sh"

# Fail loudly if a shadow did not take. The consequence of a silent miss is a skill writing
# private notes into an employer's repository, which is the one outcome this whole repo exists
# to prevent.
bash "${JOB_SKILLS}/scripts/link-skills.sh" --check
