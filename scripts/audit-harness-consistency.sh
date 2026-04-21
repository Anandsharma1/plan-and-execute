#!/usr/bin/env bash
# audit-harness-consistency.sh -- internal consistency audit for plan-and-execute.
#
# Run from the plan-and-execute repo root (the script cd's to its parent first).
# Verifies:
#   1. no stale severity rubric (Critical/Important/Minor)
#   2. no legacy reviewer-prompt injection sections (implementer/agent claims)
#   3. preamble-first loading wired in every reviewer prompt
#   4. required escape-class and dispatch-discipline clauses are present
#   5. mirror parity for files shared across install mirrors
#
# Exit status: 0 on clean pass, 1 on any failed check.

set -u

cd "$(cd "$(dirname "$0")"/.. && pwd)"

FAIL=0
MIRRORS=(.claude .agents .cursor .github .gemini .codex)

# Files that should be byte-identical between the top-level and every mirror.
# SKILL.md is intentionally excluded -- it carries per-mirror hooks-table adaptations.
SHARED_PE_FILES=(
  HELP.md
  code-quality-reviewer-prompt.md
  spec-reviewer-prompt.md
  agent-spec-reviewer-prompt.md
)
SHARED_TEMPLATES=(
  templates/claude-md-agent-dispatch-discipline.md
  templates/domain-reviewer-template.md
  templates/review-preamble-template.md
  templates/review-standards-template.md
  templates/project-config-example.yaml
)

ok()   { printf '  OK   %s\n' "$1"; }
fail() { printf '  FAIL %s\n' "$1"; FAIL=$((FAIL+1)); }
section() { printf '\n== %s ==\n' "$1"; }

# --- Check 1: stale severity rubric --------------------------------------
section "Stale severity rubric (Critical/Important/Minor)"
stale=$(grep -REn 'Critical\s*/\s*Important\s*/\s*Minor' --include='*.md' --include='*.yaml' . 2>/dev/null || true)
if [ -z "$stale" ]; then
  ok "no stale rubric residue"
else
  fail "stale 'Critical/Important/Minor' trio present:"
  printf '%s\n' "$stale"
fi

# --- Check 2: legacy reviewer-prompt injection sections ------------------
section "Legacy implementer/agent-claims injection sections"
for pat in \
  "What Was Implemented" \
  "What Implementer Claims They Built" \
  "Agent's Claimed Outputs" \
  "Completion Verdict"
do
  files=$(grep -RlF "$pat" --include='*.md' . 2>/dev/null || true)
  if [ -z "$files" ]; then
    ok "no '$pat'"
  else
    fail "legacy section '$pat' found in:"
    printf '%s\n' "$files"
  fi
done

# --- Check 3: preamble-first wiring in reviewer entry points ------------
section "Preamble-first loading wired"
for f in \
  code-quality-reviewer-prompt.md \
  spec-reviewer-prompt.md \
  agent-spec-reviewer-prompt.md \
  domain-code-review/SKILL.md \
  SKILL.md
do
  if [ ! -f "$f" ]; then
    fail "missing file: $f"
    continue
  fi
  if grep -qF '${REVIEW_PREAMBLE}' "$f"; then
    ok "$f references \${REVIEW_PREAMBLE}"
  else
    fail "$f does not reference \${REVIEW_PREAMBLE}"
  fi
done

# --- Check 4: required clauses in templates -----------------------------
section "Required clauses in shared templates"

# ImportError-shadows anti-pattern in standards + preamble template
for f in templates/review-standards-template.md templates/review-preamble-template.md; do
  if grep -qE 'ImportError.*shadows' "$f" 2>/dev/null; then
    ok "$f carries ImportError-shadows clause"
  else
    fail "$f missing ImportError-shadows clause"
  fi
done

# Dispatch-discipline sub-sections
for pat in \
  "Carry open issues forward" \
  "Sibling-pattern enforcement" \
  "Write learnings back" \
  "Parallel reviewers"
do
  if grep -qF "$pat" templates/claude-md-agent-dispatch-discipline.md 2>/dev/null; then
    ok "dispatch discipline carries '$pat'"
  else
    fail "dispatch discipline missing '$pat'"
  fi
done

# --- Check 5: mirror parity for shared files ---------------------------
section "Mirror parity for shared files"
drift=0
for m in "${MIRRORS[@]}"; do
  for f in "${SHARED_PE_FILES[@]}" "${SHARED_TEMPLATES[@]}"; do
    mfile="$m/skills/plan-and-execute/$f"
    if [ ! -f "$mfile" ]; then
      fail "missing mirror file: $mfile"
      drift=$((drift+1))
      continue
    fi
    if ! diff -q "$f" "$mfile" >/dev/null 2>&1; then
      fail "drift: $mfile differs from top-level"
      drift=$((drift+1))
    fi
  done
  dcr="$m/skills/domain-code-review/SKILL.md"
  if [ ! -f "$dcr" ]; then
    fail "missing mirror file: $dcr"
    drift=$((drift+1))
  elif ! diff -q domain-code-review/SKILL.md "$dcr" >/dev/null 2>&1; then
    fail "drift: $dcr differs from top-level"
    drift=$((drift+1))
  fi
done
if [ "$drift" -eq 0 ]; then
  ok "all 6 mirrors in parity on ${#SHARED_PE_FILES[@]} plan-and-execute files + ${#SHARED_TEMPLATES[@]} templates + domain-code-review/SKILL.md"
fi

# --- Summary ------------------------------------------------------------
echo
if [ "$FAIL" -eq 0 ]; then
  printf 'RESULT: all harness consistency checks passed\n'
  exit 0
else
  printf 'RESULT: %d check(s) failed\n' "$FAIL"
  exit 1
fi
