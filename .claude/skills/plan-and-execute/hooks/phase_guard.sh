#!/usr/bin/env bash
# plan-and-execute phase guard — registered as a Stop hook by install.sh.
#
# Blocks session exit when a run is in Phase 5/6 and not complete/failed.
# On a stop_hook_active retry loop, writes aborted_by_phase_guard and exits cleanly.
#
# Escape hatches:
#   1. Set status="failed" in .plan-and-execute.state.json  (emergency bypass)
#   2. Write .claude/awaiting-user  (run_id + phase + reason)  to allow a pause
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_FILE="$PROJECT_DIR/.plan-and-execute.state.json"

[ -f "$STATE_FILE" ] || exit 0

HOOK_PAYLOAD="$(cat || true)"

PROJECT_DIR="$PROJECT_DIR" STATE_FILE="$STATE_FILE" HOOK_PAYLOAD="$HOOK_PAYLOAD" python3 - <<'PY'
import json, os, sys, tempfile, time
from pathlib import Path

project_dir = Path(os.environ["PROJECT_DIR"])
state_path  = Path(os.environ["STATE_FILE"])
sentinel    = project_dir / ".claude" / "awaiting-user"
grace       = project_dir / ".claude" / "awaiting-user-grace.json"

TERMINAL  = {"complete", "failed"}
BLOCKING  = {"in_progress", "aborted_by_phase_guard"}
GRACE_TTL = 120  # seconds


def log(msg):
    print(f"plan-and-execute phase_guard: {msg}", file=sys.stderr)


def is_strict_int(v):
    return isinstance(v, int) and not isinstance(v, bool)


def atomic_write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(prefix=path.name + ".", suffix=".tmp", dir=str(path.parent))
    try:
        with os.fdopen(fd, "w") as f:
            json.dump(data, f, indent=2); f.write("\n"); f.flush(); os.fsync(f.fileno())
        os.replace(tmp, str(path))
    except BaseException:
        try: Path(tmp).unlink()
        except OSError: pass
        raise


# --- Parse payload ---
try:
    payload = json.loads(os.environ.get("HOOK_PAYLOAD", "{}") or "{}")
except json.JSONDecodeError:
    payload = {}

stop_hook_active = bool(payload.get("stop_hook_active"))
session_id       = str(payload.get("session_id") or "")

# --- Read state ---
try:
    state = json.loads(state_path.read_text())
    if not isinstance(state, dict):
        raise ValueError("not a JSON object")
except (json.JSONDecodeError, OSError, ValueError) as e:
    log(f"cannot read state file: {e}. Blocking. Fix or delete {state_path} to unblock.")
    print(f"BLOCK: state file unreadable — fix or delete {state_path}.", file=sys.stderr)
    sys.exit(2)

status    = state.get("status", "")
raw_phase = state.get("phase")
run_id    = state.get("run_id", "<unknown>")

# Terminal — always pass
if status in TERMINAL:
    sys.exit(0)

# Phase must be a real int
if not is_strict_int(raw_phase):
    log(f"malformed 'phase' ({raw_phase!r}) in {state_path}. Blocking.")
    print(f"BLOCK: malformed phase in state file — fix {state_path}.", file=sys.stderr)
    sys.exit(2)
phase = raw_phase

# Only gate phases 5+
if phase < 5:
    sys.exit(0)

# Non-blocking status — pass (unexpected status visible in state file)
if status not in BLOCKING:
    sys.exit(0)

# --- Awaiting-user sentinel ---
if sentinel.exists():
    try:
        s = json.loads(sentinel.read_text())
        if (isinstance(s, dict) and s.get("run_id") == run_id
                and s.get("phase") == phase and s.get("reason")):
            sentinel.unlink()
            try:
                atomic_write(grace, {
                    "run_id": run_id, "phase": phase,
                    "session_id": session_id,
                    "expires_at": time.time() + GRACE_TTL,
                })
            except Exception:
                pass
            log(f"awaiting-user sentinel honored for run '{run_id}' phase {phase}.")
            sys.exit(0)
    except (json.JSONDecodeError, OSError):
        pass
    try: sentinel.unlink()
    except OSError: pass

# --- Grace receipt (immediate retry after sentinel was consumed) ---
if stop_hook_active and grace.exists():
    try:
        g = json.loads(grace.read_text())
        if (isinstance(g, dict) and g.get("run_id") == run_id
                and g.get("phase") == phase
                and time.time() < float(g.get("expires_at", 0))):
            grace.unlink()
            log(f"awaiting-user grace receipt honored for run '{run_id}'.")
            sys.exit(0)
    except (json.JSONDecodeError, OSError):
        pass
    try: grace.unlink()
    except OSError: pass

# --- Loop-break on stop_hook_active retry ---
if stop_hook_active:
    if status == "in_progress":
        new_state = {**state,
            "status": "aborted_by_phase_guard",
            "aborted_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
            "aborted_at_phase": phase,
            "abort_reason": "phase gate enforced; session exited via retry loop-break",
        }
        try:
            atomic_write(state_path, new_state)
            log(f"run '{run_id}' phase {phase}: set to aborted_by_phase_guard.")
        except Exception as e:
            log(f"WARNING: could not write aborted_by_phase_guard: {e}. "
                f"Manually set status in {state_path} to unblock next session.")
    else:
        log(f"run '{run_id}' already aborted_by_phase_guard — allowing exit.")
    sys.exit(0)

# --- Block ---
if status == "aborted_by_phase_guard":
    print(
        f"BLOCK: run '{run_id}' is aborted_by_phase_guard at phase {phase}. "
        f"Reconcile (Session Recovery Step A) or set status='failed' in {state_path}.",
        file=sys.stderr,
    )
else:
    print(
        f"BLOCK: run '{run_id}' is in_progress at phase {phase}. "
        f"Complete Phase {phase} gates before exiting. "
        f"Emergency bypass: set status='failed' in {state_path}.",
        file=sys.stderr,
    )
sys.exit(2)
PY
