#!/usr/bin/env bash
# plan-and-execute phase guard — registered as a Stop hook by install.sh.
# Blocks session exit when a run is in Phase 5/6 and status is not "complete".
# No-op when state file is absent, status is "complete", or phase < 5.
set -euo pipefail

STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.plan-and-execute.state.json"

[ -f "$STATE_FILE" ] || exit 0

python3 - "$STATE_FILE" <<'PY'
import json, sys

try:
    d = json.load(open(sys.argv[1]))
except (json.JSONDecodeError, OSError) as e:
    print(f"plan-and-execute phase_guard: could not read state file: {e}", file=sys.stderr)
    sys.exit(0)  # don't block on corrupt state

status = d.get("status", "")
phase  = int(d.get("phase", 0))
run_id = d.get("run_id", d.get("feature_slug", "<unknown>"))

# Only gate execution and closeout phases
if phase < 5:
    sys.exit(0)

# status=="complete" is only written at the end of Phase 6 — clear the gate
if status == "complete":
    sys.exit(0)

if status == "in_progress":
    print(
        f"BLOCK: plan-and-execute run '{run_id}' is in_progress at phase {phase}. "
        f"Complete all Phase {'5' if phase == 5 else '6'} gates before exiting. "
        f"Emergency bypass: set status='failed' in {sys.argv[1]}.",
        file=sys.stderr,
    )
    sys.exit(2)

sys.exit(0)
PY
