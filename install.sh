#!/bin/bash
set -euo pipefail

# Bootstrap plan-and-execute templates into a target project.
# Usage: ./install.sh /path/to/your/project
# Safe to re-run — never overwrites existing files.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: Target directory '$TARGET' does not exist."
  exit 1
fi

copy_if_missing() {
  local src="$1" dest="$2"
  if [ -f "$dest" ]; then
    echo "  SKIP (exists): $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  CREATED: $dest"
  fi
}

echo "Bootstrapping plan-and-execute templates into: $TARGET"
echo ""

copy_if_missing "$SCRIPT_DIR/templates/review-standards-template.md" "$TARGET/docs/review-standards.md"
copy_if_missing "$SCRIPT_DIR/templates/env-config-policy-template.md" "$TARGET/docs/env-config-policy.md"
copy_if_missing "$SCRIPT_DIR/templates/domain-reviewer-template.md" "$TARGET/.claude/agents/domain-reviewer.md"
copy_if_missing "$SCRIPT_DIR/templates/project-config-example.yaml" "$TARGET/.claude/project-config.yaml"

echo ""
echo "Done. Next steps:"
echo "  1. Edit docs/review-standards.md — customize sections 1-5 for your domain"
echo "  2. Edit docs/env-config-policy.md — adjust rules for your stack"
echo "  3. Edit .claude/agents/domain-reviewer.md — fill in domain-specific review criteria"
echo "  4. Edit .claude/project-config.yaml — set your test/lint/security commands"
echo ""
echo "See HELP.md for full usage instructions."
