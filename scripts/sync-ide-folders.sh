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
#   - domain-code-review skill (synced as sibling, not nested)
#
# IDE directories:
#   .cursor/skills/plan-and-execute/
#   .cursor/skills/domain-code-review/   (sibling skill)
#   .codex/skills/plan-and-execute/
#   .codex/skills/domain-code-review/
#   .github/skills/plan-and-execute/    (GitHub Copilot)
#   .github/skills/domain-code-review/
#   .gemini/skills/plan-and-execute/
#   .gemini/skills/domain-code-review/
#   .agents/skills/plan-and-execute/    (SkillKit / npx skills)
#   .agents/skills/domain-code-review/

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# IDE targets (dir : frontmatter style)
# "full" = user-invokable + argument-hint (Claude Code, Cursor, Codex, Copilot, SkillKit)
# "minimal" = name + description only (Gemini)
declare -A TARGETS=(
  [".claude/skills/plan-and-execute"]="full"
  [".cursor/skills/plan-and-execute"]="full"
  [".codex/skills/plan-and-execute"]="full"
  [".github/skills/plan-and-execute"]="full"
  [".gemini/skills/plan-and-execute"]="minimal"
  [".agents/skills/plan-and-execute"]="full"
)
TARGET_ORDER=(
  ".claude/skills/plan-and-execute"
  ".cursor/skills/plan-and-execute"
  ".codex/skills/plan-and-execute"
  ".github/skills/plan-and-execute"
  ".gemini/skills/plan-and-execute"
  ".agents/skills/plan-and-execute"
)

# Files to sync (relative to repo root)
PROMPT_FILES=(
  "implementer-prompt.md"
  "spec-reviewer-prompt.md"
  "agent-spec-reviewer-prompt.md"
  "code-quality-reviewer-prompt.md"
  "setup-prompt.md"
  "HELP.md"
)

CLAUDE_HOOK_FILES=(
  "hooks/block_sensitive_files.sh"
  "hooks/python_post_edit.sh"
  "hooks/phase_guard.sh"
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
BEST_EFFORT=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      DRY_RUN=true
      ;;
    --best-effort)
      BEST_EFFORT=true
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--dry-run] [--best-effort]" >&2
      exit 2
      ;;
  esac
  shift
done

if $DRY_RUN; then
  echo "[DRY RUN] No files will be written."
fi
if $BEST_EFFORT; then
  echo "[BEST EFFORT] Copy failures will be reported but will not fail the run."
fi
if $DRY_RUN || $BEST_EFFORT; then
  echo ""
fi

SYNC_FAILED=false
FAILED_TARGETS=()
STAGE_TMP=""
declare -a STAGED_TEMPS=()
declare -a STAGED_DESTS=()
declare -a COMMIT_BACKUP_DESTS=()
declare -a COMMIT_BACKUP_PATHS=()
declare -A COMMITTED_DESTS=()
CLAUDE_PHASE_GUARD_DEST=".claude/skills/plan-and-execute/hooks/phase_guard.sh"
CLAUDE_LEGACY_HOOK=""

warn_sync() {
  echo "  WARNING: $1"
}

record_sync_failure() {
  SYNC_FAILED=true
  FAILED_TARGETS+=("$1")
}

should_continue_after_failure() {
  $BEST_EFFORT
}

cleanup_staged_files() {
  local tmp
  for tmp in "${STAGED_TEMPS[@]}"; do
    if [ -n "$tmp" ] && [ -e "$tmp" ]; then
      rm -f "$tmp"
    fi
  done
  STAGED_TEMPS=()
  STAGED_DESTS=()
  STAGE_TMP=""
}

remember_staged_file() {
  STAGED_TEMPS+=("$1")
  STAGED_DESTS+=("$2")
}

record_commit_backup() {
  COMMIT_BACKUP_DESTS+=("$1")
  COMMIT_BACKUP_PATHS+=("$2")
}

cleanup_commit_backups() {
  local backup
  for backup in "${COMMIT_BACKUP_PATHS[@]}"; do
    if [ -n "$backup" ] && [ "$backup" != "__MISSING__" ] && [ -e "$backup" ]; then
      rm -f "$backup"
    fi
  done
  COMMIT_BACKUP_DESTS=()
  COMMIT_BACKUP_PATHS=()
}

cleanup_temp_artifacts() {
  cleanup_staged_files
  cleanup_commit_backups
}

rollback_committed_files() {
  local idx dest backup had_restore_failure=0
  for ((idx=${#COMMIT_BACKUP_DESTS[@]} - 1; idx>=0; idx--)); do
    dest="${COMMIT_BACKUP_DESTS[$idx]}"
    backup="${COMMIT_BACKUP_PATHS[$idx]}"
    if [ "$backup" = "__MISSING__" ]; then
      rm -f "$dest"
    elif [ -e "$backup" ]; then
      if ! mv -f "$backup" "$dest" 2>/dev/null; then
        warn_sync "could not roll back '$dest' from '$backup' — backup preserved at '$backup' for manual recovery"
        had_restore_failure=1
      fi
    fi
  done
  COMMITTED_DESTS=()
  if [ "$had_restore_failure" -eq 0 ]; then
    cleanup_commit_backups
  else
    # At least one restore failed. Preserve remaining backup files so the user can
    # recover manually — do NOT call cleanup_commit_backups here. Only clear the
    # tracking arrays; the backup files themselves stay on disk.
    COMMIT_BACKUP_DESTS=()
    COMMIT_BACKUP_PATHS=()
  fi
}

backup_dest_for_commit() {
  local dest="$1" backup=""
  if [ -e "$dest" ]; then
    if ! backup="$(mktemp "${dest}.rollback.XXXXXX")"; then
      warn_sync "could not allocate rollback temp for $dest"
      record_sync_failure "$dest"
      return 1
    fi
    if ! cp -a "$dest" "$backup" 2>/dev/null; then
      warn_sync "could not back up existing destination $dest before commit"
      record_sync_failure "$dest"
      rm -f "$backup"
      return 1
    fi
  else
    backup="__MISSING__"
  fi
  record_commit_backup "$dest" "$backup"
}

trap cleanup_temp_artifacts EXIT

prepare_stage_tmp() {
  local dest="$1"
  STAGE_TMP=""

  if ! mkdir -p "$(dirname "$dest")" 2>/dev/null; then
    warn_sync "could not create parent directory for $dest"
    record_sync_failure "$dest"
    return 1
  fi

  # Stage beside the live destination so final promotion stays on the same
  # filesystem and default mode can validate every write before any live file
  # is replaced.
  if ! STAGE_TMP="$(mktemp "${dest}.tmp.XXXXXX")"; then
    warn_sync "could not allocate temp file for $dest"
    record_sync_failure "$dest"
    return 1
  fi
}

stage_file() {
  local src="$1" dest="$2"
  if $DRY_RUN; then
    if [ -f "$dest" ] && diff -q "$src" "$dest" >/dev/null 2>&1; then
      echo "  OK (in sync): $dest"
    else
      echo "  WOULD SYNC: $src -> $dest"
    fi
  else
    if ! prepare_stage_tmp "$dest"; then
      if ! should_continue_after_failure; then
        return 1
      fi
      return 0
    fi
    if cp -p "$src" "$STAGE_TMP" 2>/dev/null; then
      remember_staged_file "$STAGE_TMP" "$dest"
    else
      warn_sync "could not sync $src -> $dest"
      record_sync_failure "$dest"
      rm -f "$STAGE_TMP"
      STAGE_TMP=""
      if ! should_continue_after_failure; then
        return 1
      fi
      return 0
    fi
  fi
}

stage_skill_md() {
  local dest="$1" content="$2"
  if $DRY_RUN; then
    echo "  WOULD SYNC: SKILL.md -> $dest"
    return 0
  fi

  if ! prepare_stage_tmp "$dest"; then
    if ! should_continue_after_failure; then
      return 1
    fi
    return 0
  fi

  if ! printf '%s\n' "$content" > "$STAGE_TMP"; then
    warn_sync "could not write temp file for $dest"
    record_sync_failure "$dest"
    rm -f "$STAGE_TMP"
    STAGE_TMP=""
    if ! should_continue_after_failure; then
      return 1
    fi
    return 0
  fi

  remember_staged_file "$STAGE_TMP" "$dest"
}

commit_staged_files() {
  local i tmp dest
  for i in "${!STAGED_DESTS[@]}"; do
    tmp="${STAGED_TEMPS[$i]}"
    dest="${STAGED_DESTS[$i]}"
    if ! backup_dest_for_commit "$dest"; then
      rm -f "$tmp"
      if ! should_continue_after_failure; then
        rollback_committed_files
        cleanup_staged_files
        return 1
      fi
      continue
    fi
    if mv -f "$tmp" "$dest" 2>/dev/null; then
      COMMITTED_DESTS["$dest"]=1
      echo "  SYNCED: $dest"
    else
      warn_sync "could not commit staged file -> $dest"
      record_sync_failure "$dest"
      rm -f "$tmp"
      if ! should_continue_after_failure; then
        rollback_committed_files
        cleanup_staged_files
        return 1
      fi
    fi
  done
  cleanup_staged_files
  # Deliberately do NOT call cleanup_commit_backups here: keeping the backup data
  # alive lets the caller roll back committed files if post-commit cleanup (e.g.
  # legacy-hook deletion) subsequently fails.  The caller is responsible for
  # calling cleanup_commit_backups on the success path, and rollback_committed_files
  # (which internally calls cleanup_commit_backups) on the failure path.
}

remove_claude_legacy_hook_if_safe() {
  local legacy_hook="$1"

  if [ -z "$legacy_hook" ]; then
    return 0
  fi

  if $DRY_RUN; then
    if [ -e "$legacy_hook" ]; then
      echo "  WOULD REMOVE: $legacy_hook"
    fi
    return 0
  fi

  if [ ! -e "$legacy_hook" ]; then
    return 0
  fi

  # Gate removal on the replacement file existing at the target, not on whether
  # phase_guard.sh happened to be rewritten during this particular sync run. If
  # phase_guard.sh is already in sync from a prior run, the legacy hook can still
  # be safely removed.
  local replacement="${legacy_hook%.py}.sh"
  if [ ! -e "$replacement" ]; then
    warn_sync "skipping legacy hook removal: replacement $replacement not found at target"
    return 0
  fi

  if rm -f "$legacy_hook"; then
    echo "  REMOVED: $legacy_hook"
  else
    warn_sync "could not remove legacy hook $legacy_hook"
    record_sync_failure "$legacy_hook"
    if ! should_continue_after_failure; then
      return 1
    fi
    return 0
  fi
}

SKILL_BODY=$(awk 'BEGIN{n=0} /^---$/{n++; if(n==2){found=1; next}} found{print}' SKILL.md)

for target in "${TARGET_ORDER[@]}"; do
  style="${TARGETS[$target]}"
  echo "=== $target (frontmatter: $style) ==="

  # Sync SKILL.md with adapted frontmatter
  SKILL_DEST="$target/SKILL.md"

  if [[ "$style" == "minimal" ]]; then
    FRONTMATTER="$MINIMAL_FRONTMATTER"
  else
    FRONTMATTER="$FULL_FRONTMATTER"
  fi

  if ! stage_skill_md "$SKILL_DEST" "$FRONTMATTER
$SKILL_BODY"; then
    break
  fi

  # Sync prompt templates
  for file in "${PROMPT_FILES[@]}"; do
    if [ -f "$file" ]; then
      if ! stage_file "$file" "$target/$file"; then
        break 2
      fi
    fi
  done

  # Claude is the only target that ships executable hook scripts as part of
  # the skill bundle. Keep that copy in sync with the repo root and prune the
  # removed Python phase guard so packaging doesn't resurrect it.
  if [[ "$target" == ".claude/skills/plan-and-execute" ]]; then
    for hook in "${CLAUDE_HOOK_FILES[@]}"; do
      if [ -f "$hook" ]; then
        if ! stage_file "$hook" "$target/$hook"; then
          break 2
        fi
      fi
    done

    CLAUDE_LEGACY_HOOK="$target/hooks/phase_guard.py"
  fi

  # Sync templates directory
  if [ -d "$TEMPLATE_DIR" ]; then
    for tmpl in "$TEMPLATE_DIR"/*; do
      if [ -f "$tmpl" ]; then
        if ! stage_file "$tmpl" "$target/$tmpl"; then
          break 2
        fi
      fi
    done
  fi

  # Sync domain-code-review as a sibling skill (e.g. .cursor/skills/domain-code-review/)
  SIBLING_DIR="$(dirname "$target")/domain-code-review"
  if [ -d "domain-code-review" ]; then
    for f in domain-code-review/*; do
      if [ -f "$f" ]; then
        local_name="$(basename "$f")"
        if ! stage_file "$f" "$SIBLING_DIR/$local_name"; then
          break 2
        fi
      fi
    done
  fi

  echo ""
done

if ! $DRY_RUN; then
  if $SYNC_FAILED && ! $BEST_EFFORT; then
    cleanup_staged_files
  else
    commit_succeeded=true
    if ! commit_staged_files; then
      cleanup_staged_files
      commit_succeeded=false
    fi
    if $commit_succeeded; then
      if ! remove_claude_legacy_hook_if_safe "$CLAUDE_LEGACY_HOOK"; then
        # Default mode: legacy cleanup failed after files were already committed.
        # Roll back to keep the "fail closed" guarantee — partial releases must not
        # be published.  Best-effort mode never reaches here because the helper
        # returns 0 even on failure in that mode.
        rollback_committed_files
      else
        # Full success: release the commit backups.
        cleanup_commit_backups
      fi
    fi
  fi
fi

if $SYNC_FAILED; then
  echo ""
  echo "Sync completed with failures:"
  for failed in "${FAILED_TARGETS[@]}"; do
    echo "  - $failed"
  done
  if $BEST_EFFORT; then
    echo ""
    echo "Done (best effort)."
    exit 0
  fi
  echo ""
  echo "Sync incomplete. Re-run with --best-effort only if partial updates are acceptable."
  exit 1
fi

echo "Done."
