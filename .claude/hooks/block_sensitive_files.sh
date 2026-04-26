#!/usr/bin/env bash
# PreToolUse hook: block edits on .env, credential, and key files.
# Register in .claude/settings.json under PreToolUse, matcher "Edit|Write|MultiEdit".
input=$(cat)
FILE=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
case "$FILE" in
  *.env.example|*.env.sample|*.env.template) ;;
  *.env|*.env.local|*.env.development|*.env.production|*.env.test|*.env.staging|*credentials*|*sa-key*)
    echo "BLOCK: Sensitive file — edit manually: $FILE" >&2
    exit 2
    ;;
esac
