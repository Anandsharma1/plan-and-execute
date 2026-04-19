#!/usr/bin/env bash
# PostToolUse hook: auto-format Python files with ruff + syntax-check after each edit.
# Register in .claude/settings.json under PostToolUse, matcher "Edit|Write|MultiEdit".
# For JS/TS projects, adapt to use npx eslint --fix / npx prettier --write.
input=$(cat)
FILE=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in
  *.py)
    uv run ruff check --fix --quiet "$FILE" 2>/dev/null
    uv run ruff format --quiet "$FILE" 2>/dev/null
    uv run python -m py_compile "$FILE" 2>/dev/null
    ;;
esac
exit 0
