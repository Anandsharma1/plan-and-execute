#!/usr/bin/env bash
# install-git-hooks.sh -- one-time setup for plan-and-execute contributor hooks.
#
# Points git at the versioned .githooks/ directory so every contributor runs
# the same hooks. Safe to re-run; idempotent.
#
# What this installs:
#   .githooks/pre-commit -- runs scripts/audit-harness-consistency.sh before
#                           each commit; blocks commits on harness/mirror drift.

set -euo pipefail

repo_root=$(git rev-parse --show-toplevel)
cd "$repo_root"

if [ ! -d .githooks ]; then
  echo "install-git-hooks: .githooks directory not found at $repo_root/.githooks" >&2
  exit 1
fi

git config core.hooksPath .githooks
chmod +x .githooks/* 2>/dev/null || true

printf 'Installed: core.hooksPath -> .githooks\n'
printf 'Active hooks:\n'
for f in .githooks/*; do
  [ -e "$f" ] || continue
  printf '  %s\n' "$f"
done
