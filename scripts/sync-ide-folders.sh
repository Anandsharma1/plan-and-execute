#!/bin/bash
set -euo pipefail

# Sync canonical files to IDE-specific skill directories.
# Run from repo root before releases: ./scripts/sync-ide-folders.sh
#
# What it syncs:
#   - SKILL.md (with adapted frontmatter per IDE)
#   - Prompt templates (implementer, reviewers, etc.)
#   - Bootstrap templates (review-standards, env-config, etc.)
#   - Supporting files (setup-prompt, task-plan-template, etc.)
#
# IDE directories:
#   .cursor/skills/plan-and-execute/
#   .codex/skills/plan-and-execute/
#   .github/skills/plan-and-execute/    (GitHub Copilot)
#   .gemini/skills/plan-and-execute/
#   .agents/skills/plan-and-execute/    (SkillKit / npx skills)

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# IDE targets (dir : frontmatter style)
# "full" = user-invokable + argument-hint (Claude Code, Cursor, Codex, Copilot, SkillKit)
# "minimal" = name + description only (Gemini)
declare -A TARGETS=(
  [".cursor/skills/plan-and-execute"]="full"
  [".codex/skills/plan-and-execute"]="full"
  [".github/skills/plan-and-execute"]="full"
  [".gemini/skills/plan-and-execute"]="minimal"
  [".agents/skills/plan-and-execute"]="full"
)

# Files to sync (relative to repo root)
PROMPT_FILES=(
  "implementer-prompt.md"
  "spec-reviewer-prompt.md"
  "agent-spec-reviewer-prompt.md"
  "code-quality-reviewer-prompt.md"
  "task-plan-template.md"
  "review-learnings-template.md"
  "setup-prompt.md"
  "HELP.md"
)

TEMPLATE_DIR="templates"

# Frontmatter variants
FULL_FRONTMATTER='---
name: plan-and-execute
description: Use when starting a multi-step feature, bugfix, or refactor that needs research, formal planning, and validated execution with persistent context across phases
user-invokable: true
argument-hint: "<feature request, bug description, or task description>"
---'

MINIMAL_FRONTMATTER='---
name: plan-and-execute
description: Use when starting a multi-step feature, bugfix, or refactor that needs research, formal planning, and validated execution with persistent context across phases
---'

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  echo "[DRY RUN] No files will be written."
  echo ""
fi

sync_file() {
  local src="$1" dest="$2"
  if $DRY_RUN; then
    if [ -f "$dest" ] && diff -q "$src" "$dest" >/dev/null 2>&1; then
      echo "  OK (in sync): $dest"
    else
      echo "  WOULD SYNC: $src -> $dest"
    fi
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  SYNCED: $dest"
  fi
}

for target in "${!TARGETS[@]}"; do
  style="${TARGETS[$target]}"
  echo "=== $target (frontmatter: $style) ==="

  # Sync SKILL.md with adapted frontmatter
  SKILL_DEST="$target/SKILL.md"
  # Extract body (everything after the closing ---)
  SKILL_BODY=$(awk 'BEGIN{n=0} /^---$/{n++; if(n==2){found=1; next}} found{print}' SKILL.md)

  if [[ "$style" == "minimal" ]]; then
    FRONTMATTER="$MINIMAL_FRONTMATTER"
  else
    FRONTMATTER="$FULL_FRONTMATTER"
  fi

  if $DRY_RUN; then
    echo "  WOULD SYNC: SKILL.md -> $SKILL_DEST (frontmatter: $style)"
  else
    echo "$FRONTMATTER" > "$SKILL_DEST"
    echo "$SKILL_BODY" >> "$SKILL_DEST"
    echo "  SYNCED: $SKILL_DEST"
  fi

  # Sync prompt templates
  for file in "${PROMPT_FILES[@]}"; do
    if [ -f "$file" ]; then
      sync_file "$file" "$target/$file"
    fi
  done

  # Sync templates directory
  if [ -d "$TEMPLATE_DIR" ]; then
    for tmpl in "$TEMPLATE_DIR"/*; do
      if [ -f "$tmpl" ]; then
        sync_file "$tmpl" "$target/$tmpl"
      fi
    done
  fi

  # Sync domain-code-review skill
  if [ -d "skills/domain-code-review" ]; then
    for f in skills/domain-code-review/*; do
      if [ -f "$f" ]; then
        sync_file "$f" "$target/$f"
      fi
    done
  fi

  echo ""
done

echo "Done."
