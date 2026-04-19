#!/usr/bin/env python3
"""Stop hook: block session exit when a plan-and-execute run is in Phase 5/6 and not complete.

Install via plan-and-execute setup (FR-7c), or manually:
  cp .claude/skills/plan-and-execute/hooks/phase_guard.py .claude/hooks/phase_guard.py
  # Add to .claude/settings.json Stop hooks:
  # {"matcher": "", "hooks": [{"type": "command", "command": "python3 .claude/hooks/phase_guard.py", "timeout": 10}]}

Gate logic (reads STATE_FILE, not task_plan.md):
  - No STATE_FILE present: no-op
  - status == "complete": no-op (Phase 6 finished cleanly)
  - phase < 5: no-op (still in planning phases)
  - phase 5 or 6 + status == "in_progress": BLOCK
  - Cannot parse STATE_FILE: no-op (don't block on corrupt state)

Emergency exit: delete .plan-and-execute.state.json to bypass the gate.
"""

from __future__ import annotations

import json
import os
import sys
from pathlib import Path


def main() -> int:
    project_dir = Path(os.environ.get("CLAUDE_PROJECT_DIR", ".")).resolve()
    state_file = project_dir / ".plan-and-execute.state.json"

    if not state_file.exists():
        return 0

    try:
        state = json.loads(state_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return 0

    status = state.get("status", "")
    phase = state.get("phase", 0)

    if status == "complete":
        return 0

    if phase < 5:
        return 0

    if status == "in_progress":
        run_id = state.get("run_id", "unknown")
        print(
            f"BLOCK: plan-and-execute run '{run_id}' is in Phase {phase} (status: in_progress).",
            file=sys.stderr,
        )
        print(
            "Complete Phase 5/6 gates and set status='complete' before stopping.",
            file=sys.stderr,
        )
        print(
            "Emergency exit: delete .plan-and-execute.state.json to bypass.",
            file=sys.stderr,
        )
        return 2

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
