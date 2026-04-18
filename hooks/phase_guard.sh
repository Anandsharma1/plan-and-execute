#!/usr/bin/env bash
# plan-and-execute phase guard — registered as a Stop hook by install.sh.
# Blocks session exit when a run is in_progress and has not reached Phase 6.
# No-op when state file is absent or status is not in_progress.
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

status   = d.get("status", "")
phase    = int(d.get("phase", 0))
slug     = d.get("feature_slug", "<unknown>")
run_id   = d.get("run_id", slug)

# "needs-policy-decision" means headless mode emitted a promotion bundle — don't re-block
if status == "in_progress" and phase < 6:
    print(
        f"BLOCK: plan-and-execute run '{run_id}' is in_progress at phase {phase}. "
        f"Phase must reach 6 (closeout) before exiting. "
        f"To bypass for rescue scenarios, set status='failed' in {sys.argv[1]}.",
        file=sys.stderr,
    )
    sys.exit(2)

sys.exit(0)
PY
