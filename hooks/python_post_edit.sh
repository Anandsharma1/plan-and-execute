#!/usr/bin/env bash
# PostToolUse hook: auto-format and syntax-check code files after each edit.
# Register in .claude/settings.json under PostToolUse, matcher "Edit|Write|MultiEdit".
#
# Activated only for file types whose case matches below — safe to install on any project.
# To add JS/TS support, uncomment the *.js|*.ts section and ensure npx is available.
input=$(cat)
FILE=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in
  *.py)
    uv run ruff check --fix --quiet "$FILE" 2>/dev/null
    uv run ruff format --quiet "$FILE" 2>/dev/null
    uv run python -m py_compile "$FILE" 2>/dev/null
    ;;
  # *.js|*.ts|*.jsx|*.tsx)
  #   npx eslint --fix --quiet "$FILE" 2>/dev/null
  #   npx prettier --write --quiet "$FILE" 2>/dev/null
  #   ;;
esac
exit 0
