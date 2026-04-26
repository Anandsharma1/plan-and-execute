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
    copy_file_atomic "$src" "$dest"
    echo "  CREATED: $dest"
  fi
}

copy_file_atomic() {
  local src="$1" dest="$2" tmp=""
  mkdir -p "$(dirname "$dest")"
  tmp="$(mktemp "${dest}.tmp.XXXXXX")"
  cleanup() {
    if [ -n "$tmp" ] && [ -e "$tmp" ]; then
      rm -f "$tmp"
    fi
  }
  trap cleanup RETURN
  cp "$src" "$tmp"
  mv -f "$tmp" "$dest"
  trap - RETURN
}

echo "Bootstrapping plan-and-execute templates into: $TARGET"
echo ""

copy_if_missing "$SCRIPT_DIR/templates/review-standards-template.md" "$TARGET/docs/review-standards.md"
copy_if_missing "$SCRIPT_DIR/templates/env-config-policy-template.md" "$TARGET/docs/env-config-policy.md"
copy_if_missing "$SCRIPT_DIR/templates/domain-reviewer-template.md" "$TARGET/.claude/agents/domain-reviewer.md"
copy_if_missing "$SCRIPT_DIR/templates/project-config-example.yaml" "$TARGET/.claude/project-config.yaml"
copy_if_missing "$SCRIPT_DIR/templates/review-preamble-template.md" "$TARGET/.claude/shared/review-preamble.md"

# --- Built-in validators (all opt-in via VALIDATORS list in project-config.yaml) ---
copy_if_missing "$SCRIPT_DIR/validators/wiring-auditor/SKILL.md"       "$TARGET/.claude/validators/wiring-auditor/SKILL.md"
copy_if_missing "$SCRIPT_DIR/validators/contract-auditor/SKILL.md"     "$TARGET/.claude/validators/contract-auditor/SKILL.md"
copy_if_missing "$SCRIPT_DIR/validators/failure-path-auditor/SKILL.md" "$TARGET/.claude/validators/failure-path-auditor/SKILL.md"
copy_if_missing "$SCRIPT_DIR/validators/mutation-site-auditor/SKILL.md" "$TARGET/.claude/validators/mutation-site-auditor/SKILL.md"
copy_if_missing "$SCRIPT_DIR/validators/evidence-verifier/SKILL.md"    "$TARGET/.claude/validators/evidence-verifier/SKILL.md"

# --- Install hooks and register in .claude/settings.json ---
HOOKS_DEST_DIR="$TARGET/.claude/hooks"
SETTINGS_FILE="$TARGET/.claude/settings.json"
LEGACY_PY_HOOK="$HOOKS_DEST_DIR/phase_guard.py"

mkdir -p "$HOOKS_DEST_DIR"

validate_hook_destination() {
  local dest="$1"
  if [ -e "$dest" ] && [ ! -f "$dest" ]; then
    echo "  ERROR: hook destination exists but is not a regular file: $dest"
    echo "         Move or remove that path, then rerun install.sh."
    exit 1
  fi
}

validate_hook_destination "$HOOKS_DEST_DIR/phase_guard.sh"
validate_hook_destination "$HOOKS_DEST_DIR/block_sensitive_files.sh"
validate_hook_destination "$HOOKS_DEST_DIR/python_post_edit.sh"

# Stage all three hook files before settings migration so the install is
# transactional: if any stage copy fails (permissions, disk full), we exit
# before touching settings.json. The EXIT trap cleans up on unexpected failure.
_pg_staged="$HOOKS_DEST_DIR/.phase_guard.sh.installing.$$"
_bs_staged="$HOOKS_DEST_DIR/.block_sensitive_files.sh.installing.$$"
_pp_staged="$HOOKS_DEST_DIR/.python_post_edit.sh.installing.$$"

_cleanup_staged_hooks() {
  rm -f "$_pg_staged" "$_bs_staged" "$_pp_staged"
}
trap _cleanup_staged_hooks EXIT

if ! cp "$SCRIPT_DIR/hooks/phase_guard.sh" "$_pg_staged" 2>/dev/null; then
  echo "  ERROR: cannot write to $HOOKS_DEST_DIR — install aborted before any changes."
  echo "         Fix permissions on $HOOKS_DEST_DIR and rerun install.sh."
  exit 1
fi
if ! cp "$SCRIPT_DIR/hooks/block_sensitive_files.sh" "$_bs_staged" 2>/dev/null; then
  echo "  ERROR: cannot stage block_sensitive_files.sh to $HOOKS_DEST_DIR — install aborted."
  exit 1
fi
if ! cp "$SCRIPT_DIR/hooks/python_post_edit.sh" "$_pp_staged" 2>/dev/null; then
  echo "  ERROR: cannot stage python_post_edit.sh to $HOOKS_DEST_DIR — install aborted."
  exit 1
fi
chmod +x "$_pg_staged" "$_bs_staged" "$_pp_staged"

# Register hooks in settings.json. Uses repo-relative command paths so
# settings.json is portable across machines.
if command -v python3 >/dev/null 2>&1; then
  python3 - "$SETTINGS_FILE" <<'PY'
import json, os, sys, tempfile

def atomic_write_json(path, data):
    parent = os.path.dirname(path) or "."
    os.makedirs(parent, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=os.path.basename(path) + ".", suffix=".tmp", dir=parent)
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2)
            f.write("\n")
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try: os.unlink(tmp)
        except OSError: pass
        raise

settings_path = sys.argv[1]

if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)
else:
    settings = {}

settings.setdefault("env", {})
settings["env"].setdefault("CLAUDE_CODE_USE_TOOL_SEARCH_TOOL", "1")
settings["env"].setdefault("CLAUDE_CODE_AUTO_COMPACT_WINDOW", "400000")

if not isinstance(settings.get("hooks"), dict):
    settings["hooks"] = {}
for hook_type in ("Stop", "PreToolUse", "PostToolUse"):
    if not isinstance(settings["hooks"].get(hook_type), list):
        settings["hooks"][hook_type] = []

def cmd_contains(cmd, fragment):
    return isinstance(cmd, str) and fragment in cmd

def iter_commands(hook_list):
    for entry in hook_list:
        if not isinstance(entry, dict):
            continue
        if isinstance(entry.get("command"), str):
            yield entry["command"]
        for h in (entry.get("hooks") or []):
            if isinstance(h, dict) and isinstance(h.get("command"), str):
                yield h["command"]

def already_registered(hook_list, filename):
    return any(cmd_contains(cmd, filename) for cmd in iter_commands(hook_list))

def drop_phase_guard_py(hook_list):
    new_list = []
    removed = 0
    for entry in hook_list:
        if not isinstance(entry, dict):
            new_list.append(entry)
            continue
        if cmd_contains(entry.get("command"), "phase_guard.py"):
            removed += 1
            continue
        inner = entry.get("hooks") or []
        if isinstance(inner, list):
            filtered = [h for h in inner
                        if not (isinstance(h, dict)
                                and cmd_contains(h.get("command"), "phase_guard.py"))]
            removed += len(inner) - len(filtered)
            if filtered != inner:
                entry = dict(entry)
                entry["hooks"] = filtered
        if entry.get("hooks") or "command" in entry:
            new_list.append(entry)
    return new_list, removed

def append_hook(hook_list, matcher, command, timeout):
    hook_list.append({"matcher": matcher,
                      "hooks": [{"type": "command", "command": command, "timeout": timeout}]})

cleaned, removed = drop_phase_guard_py(settings["hooks"]["Stop"])
if removed:
    settings["hooks"]["Stop"] = cleaned
    print(f"  MIGRATED: removed {removed} legacy phase_guard.py Stop entry(ies)")

stop_cmd    = ".claude/hooks/phase_guard.sh"
guard_cmd   = ".claude/hooks/block_sensitive_files.sh"
quality_cmd = ".claude/hooks/python_post_edit.sh"

if not already_registered(settings["hooks"]["Stop"], "phase_guard.sh"):
    append_hook(settings["hooks"]["Stop"], "", stop_cmd, 10)
    print("  REGISTERED: phase_guard.sh Stop hook")
else:
    print("  SKIP (already registered): phase_guard.sh Stop hook")

if not already_registered(settings["hooks"]["PreToolUse"], "block_sensitive_files.sh"):
    append_hook(settings["hooks"]["PreToolUse"], "Edit|Write|MultiEdit", guard_cmd, 5)
    print("  REGISTERED: block_sensitive_files.sh PreToolUse hook")
else:
    print("  SKIP (already registered): block_sensitive_files.sh PreToolUse hook")

if not already_registered(settings["hooks"]["PostToolUse"], "python_post_edit.sh"):
    append_hook(settings["hooks"]["PostToolUse"], "Edit|Write|MultiEdit", quality_cmd, 30)
    print("  REGISTERED: python_post_edit.sh PostToolUse hook")
else:
    print("  SKIP (already registered): python_post_edit.sh PostToolUse hook")

atomic_write_json(settings_path, settings)
PY
  if [ -f "$LEGACY_PY_HOOK" ]; then
    rm "$LEGACY_PY_HOOK"
    echo "  REMOVED: $LEGACY_PY_HOOK (superseded by phase_guard.sh)"
  fi
else
  echo "  WARNING: python3 not found — hooks not registered in settings.json."
  echo "           Add manually to .claude/settings.json:"
  echo "             Stop: [{matcher: \"\", hooks: [{type: command, command: .claude/hooks/phase_guard.sh, timeout: 10}]}]"
  echo "             PreToolUse: [{matcher: Edit|Write|MultiEdit, hooks: [{type: command, command: .claude/hooks/block_sensitive_files.sh, timeout: 5}]}]"
  echo "             PostToolUse: [{matcher: Edit|Write|MultiEdit, hooks: [{type: command, command: .claude/hooks/python_post_edit.sh, timeout: 30}]}]"
fi

# Finalize staged hook files now that settings.json is consistent.
finalize_staged_hook() {
  local staged="$1" final_src="$2" dest="$3"
  if [ -e "$dest" ] && [ ! -f "$dest" ]; then
    echo "  ERROR: hook destination exists but is not a regular file: $dest"
    exit 1
  fi
  if [ ! -f "$dest" ]; then
    mv "$staged" "$dest"
    chmod +x "$dest"
    echo "  CREATED: $dest"
  elif cmp -s "$final_src" "$dest"; then
    rm -f "$staged"
    echo "  UNCHANGED: $dest"
  else
    local backup="${dest}.bak.$(date -u +%Y%m%dT%H%M%SZ)"
    cp "$dest" "$backup"
    mv "$staged" "$dest"
    chmod +x "$dest"
    echo "  UPDATED: $dest (previous content backed up to $backup)"
  fi
}
finalize_staged_hook "$_pg_staged" "$SCRIPT_DIR/hooks/phase_guard.sh"           "$HOOKS_DEST_DIR/phase_guard.sh"
finalize_staged_hook "$_bs_staged" "$SCRIPT_DIR/hooks/block_sensitive_files.sh" "$HOOKS_DEST_DIR/block_sensitive_files.sh"
finalize_staged_hook "$_pp_staged" "$SCRIPT_DIR/hooks/python_post_edit.sh"      "$HOOKS_DEST_DIR/python_post_edit.sh"
trap - EXIT

# --- Interactive logging setup ---
echo ""
echo "=== Logging Configuration ==="
echo "Set up project-wide logging policy (stored in .claude/project-config.yaml)."
echo "You can skip this now and configure later by editing the config file."
echo ""

read -r -p "Configure logging now? [Y/n] " CONFIGURE_LOGGING
CONFIGURE_LOGGING="${CONFIGURE_LOGGING:-Y}"

if [[ "$CONFIGURE_LOGGING" =~ ^[Yy]$ ]]; then
  # Destination
  echo ""
  echo "Log destination:"
  echo "  1) file      — log to file only (recommended for backend services)"
  echo "  2) terminal  — log to stdout/stderr only"
  echo "  3) both      — log to file and terminal"
  read -r -p "Choose [1/2/3] (default: 1): " LOG_DEST_CHOICE
  case "${LOG_DEST_CHOICE:-1}" in
    1) LOG_DEST="file" ;;
    2) LOG_DEST="terminal" ;;
    3) LOG_DEST="both" ;;
    *) LOG_DEST="file" ;;
  esac

  # File-specific options
  LOG_FILE_PATH="logs/app.log"
  LOG_ROTATION="size"
  LOG_MAX_SIZE=10
  LOG_BACKUP_COUNT=5
  if [[ "$LOG_DEST" != "terminal" ]]; then
    read -r -p "Log file path (relative to project root) [logs/app.log]: " LOG_FILE_PATH_INPUT
    LOG_FILE_PATH="${LOG_FILE_PATH_INPUT:-logs/app.log}"

    echo ""
    echo "Log rotation policy:"
    echo "  1) size  — rotate when file exceeds max size (recommended)"
    echo "  2) time  — rotate daily"
    echo "  3) none  — no rotation"
    read -r -p "Choose [1/2/3] (default: 1): " LOG_ROT_CHOICE
    case "${LOG_ROT_CHOICE:-1}" in
      1) LOG_ROTATION="size" ;;
      2) LOG_ROTATION="time" ;;
      3) LOG_ROTATION="none" ;;
      *) LOG_ROTATION="size" ;;
    esac

    if [[ "$LOG_ROTATION" == "size" ]]; then
      read -r -p "Max file size in MB [10]: " LOG_MAX_SIZE_INPUT
      LOG_MAX_SIZE="${LOG_MAX_SIZE_INPUT:-10}"
    fi

    if [[ "$LOG_ROTATION" != "none" ]]; then
      read -r -p "Number of backup files to keep [5]: " LOG_BACKUP_INPUT
      LOG_BACKUP_COUNT="${LOG_BACKUP_INPUT:-5}"
    fi
  fi

  # Format
  echo ""
  echo "Log format:"
  echo "  1) structured  — JSON lines (recommended for production / log aggregators)"
  echo "  2) human       — human-readable text"
  read -r -p "Choose [1/2] (default: 1): " LOG_FMT_CHOICE
  case "${LOG_FMT_CHOICE:-1}" in
    1) LOG_FORMAT="structured" ;;
    2) LOG_FORMAT="human" ;;
    *) LOG_FORMAT="structured" ;;
  esac

  # Level
  echo ""
  echo "Default log level:"
  echo "  1) DEBUG    2) INFO (recommended)    3) WARNING    4) ERROR"
  read -r -p "Choose [1/2/3/4] (default: 2): " LOG_LVL_CHOICE
  case "${LOG_LVL_CHOICE:-2}" in
    1) LOG_LEVEL="DEBUG" ;;
    2) LOG_LEVEL="INFO" ;;
    3) LOG_LEVEL="WARNING" ;;
    4) LOG_LEVEL="ERROR" ;;
    *) LOG_LEVEL="INFO" ;;
  esac

  # Write logging config to project-config.yaml
  CONFIG_FILE="$TARGET/.claude/project-config.yaml"
  if grep -q "^  # logging:" "$CONFIG_FILE" 2>/dev/null || grep -q "^  logging:" "$CONFIG_FILE" 2>/dev/null; then
    TMPFILE=$(mktemp "${CONFIG_FILE}.tmp.XXXXXX")
    awk '
      /^  #? *logging:/ { skip=1; next }
      skip && /^  #? *[a-z_]+:/ && !/^  #? *(destination|file_path|rotation|max_size_mb|backup_count|format|level):/ { skip=0 }
      skip { next }
      { print }
    ' "$CONFIG_FILE" > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG_FILE"
  fi

  LOGGING_BLOCK="  logging:"
  LOGGING_BLOCK="$LOGGING_BLOCK\n    destination: \"$LOG_DEST\""
  if [[ "$LOG_DEST" != "terminal" ]]; then
    LOGGING_BLOCK="$LOGGING_BLOCK\n    file_path: \"$LOG_FILE_PATH\""
    LOGGING_BLOCK="$LOGGING_BLOCK\n    rotation: \"$LOG_ROTATION\""
    if [[ "$LOG_ROTATION" == "size" ]]; then
      LOGGING_BLOCK="$LOGGING_BLOCK\n    max_size_mb: $LOG_MAX_SIZE"
    fi
    if [[ "$LOG_ROTATION" != "none" ]]; then
      LOGGING_BLOCK="$LOGGING_BLOCK\n    backup_count: $LOG_BACKUP_COUNT"
    fi
  fi
  LOGGING_BLOCK="$LOGGING_BLOCK\n    format: \"$LOG_FORMAT\""
  LOGGING_BLOCK="$LOGGING_BLOCK\n    level: \"$LOG_LEVEL\""

  sed -i "/^  # --- Behavior ---/i\\
$(echo -e "$LOGGING_BLOCK")" "$CONFIG_FILE"

  echo ""
  echo "  Logging config written to .claude/project-config.yaml"

  LOGGING_PY="$TARGET/logging_config.py"
  if [ ! -f "$LOGGING_PY" ]; then
    cp "$SCRIPT_DIR/templates/logging_config_template.py" "$LOGGING_PY"
    sed -i "s|{{LOG_DEST}}|$LOG_DEST|g" "$LOGGING_PY"
    sed -i "s|{{LOG_FILE_PATH}}|$LOG_FILE_PATH|g" "$LOGGING_PY"
    sed -i "s|{{LOG_ROTATION}}|$LOG_ROTATION|g" "$LOGGING_PY"
    sed -i "s|{{LOG_MAX_SIZE_MB}}|$LOG_MAX_SIZE|g" "$LOGGING_PY"
    sed -i "s|{{LOG_BACKUP_COUNT}}|$LOG_BACKUP_COUNT|g" "$LOGGING_PY"
    sed -i "s|{{LOG_FORMAT}}|$LOG_FORMAT|g" "$LOGGING_PY"
    sed -i "s|{{LOG_LEVEL}}|$LOG_LEVEL|g" "$LOGGING_PY"
    echo "  CREATED: $LOGGING_PY"
  else
    echo "  SKIP (exists): $LOGGING_PY"
  fi
fi

echo ""
echo "Done. Next steps:"
echo "  1. Edit docs/review-standards.md — customize sections 1-5 for your domain"
echo "  2. Edit docs/env-config-policy.md — adjust rules for your stack"
echo "  3. Edit .claude/agents/domain-reviewer.md — fill in domain-specific review criteria"
echo "  4. Edit .claude/project-config.yaml — set your test/lint/security commands"
if [[ "${CONFIGURE_LOGGING:-N}" =~ ^[Yy]$ ]]; then
  echo "  5. Review logging_config.py — adjust if needed, then import in your app entrypoint"
fi
echo ""
echo "See HELP.md for full usage instructions."
