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
    # Replace the commented-out logging block with actual values
    # Use a temp file for portability
    TMPFILE=$(mktemp)
    awk '
      /^  #? *logging:/ { skip=1; next }
      skip && /^  #? *[a-z_]+:/ && !/^  #? *(destination|file_path|rotation|max_size_mb|backup_count|format|level):/ { skip=0 }
      skip { next }
      { print }
    ' "$CONFIG_FILE" > "$TMPFILE"
    mv "$TMPFILE" "$CONFIG_FILE"
  fi

  # Append logging block before the behavior section
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

  # Generate logging_config.py
  LOGGING_PY="$TARGET/logging_config.py"
  if [ ! -f "$LOGGING_PY" ]; then
    cp "$SCRIPT_DIR/templates/logging_config_template.py" "$LOGGING_PY"

    # Substitute placeholders
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
