import json
import os
import subprocess
import tempfile
import time
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
PHASE_GUARD = REPO_ROOT / "hooks" / "phase_guard.sh"
TEST_TMP_ROOT = REPO_ROOT / ".tmp-test-work"


class PhaseGuardTest(unittest.TestCase):
    def setUp(self):
        TEST_TMP_ROOT.mkdir(parents=True, exist_ok=True)
        self.tempdir = tempfile.TemporaryDirectory(dir=TEST_TMP_ROOT)
        self.project_dir = Path(self.tempdir.name)
        self.claude_dir = self.project_dir / ".claude"
        self.claude_dir.mkdir()
        (self.project_dir / ".plan-and-execute.state.json").write_text(
            json.dumps({"run_id": "run-123", "phase": 5, "status": "in_progress"})
        )

    def tearDown(self):
        self.tempdir.cleanup()

    def write_state(self, **kwargs):
        (self.project_dir / ".plan-and-execute.state.json").write_text(json.dumps(kwargs))

    def write_sentinel(self, run_id="run-123", phase=5, reason="waiting"):
        (self.claude_dir / "awaiting-user").write_text(
            json.dumps({"run_id": run_id, "phase": phase, "reason": reason})
        )

    def run_hook(self, payload):
        env = os.environ.copy()
        env["CLAUDE_PROJECT_DIR"] = str(self.project_dir)
        return subprocess.run(
            ["bash", str(PHASE_GUARD)],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )

    # --- Basic gate ---

    def test_missing_state_file_exits_0(self):
        (self.project_dir / ".plan-and-execute.state.json").unlink()
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 0)

    def test_terminal_complete_exits_0(self):
        self.write_state(run_id="run-123", phase=5, status="complete")
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 0)

    def test_terminal_failed_exits_0(self):
        self.write_state(run_id="run-123", phase=5, status="failed")
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 0)

    def test_terminal_with_malformed_phase_exits_0(self):
        # Terminal check runs before phase validation — documented bypass works even
        # when state has a bad phase field.
        for status in ("complete", "failed"):
            for bad_phase in (None, "oops", True):
                with self.subTest(status=status, phase=bad_phase):
                    self.write_state(run_id="r", phase=bad_phase, status=status)
                    r = self.run_hook({"stop_hook_active": False})
                    self.assertEqual(r.returncode, 0)

    def test_phase_below_5_exits_0(self):
        self.write_state(run_id="run-123", phase=4, status="in_progress")
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 0)

    def test_in_progress_phase_5_blocks(self):
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 2)
        self.assertIn("BLOCK", r.stderr)

    def test_aborted_by_phase_guard_blocks(self):
        self.write_state(run_id="run-123", phase=5, status="aborted_by_phase_guard")
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 2)

    def test_unexpected_status_passes(self):
        # Unknown status is not in BLOCKING — let the developer handle it manually.
        self.write_state(run_id="run-123", phase=5, status="paused")
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 0)

    def test_corrupt_state_blocks(self):
        (self.project_dir / ".plan-and-execute.state.json").write_text("{bad json")
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 2)

    def test_malformed_phase_blocks(self):
        for bad in (None, "five", True, 3.0, []):
            with self.subTest(phase=bad):
                self.write_state(run_id="r", phase=bad, status="in_progress")
                r = self.run_hook({"stop_hook_active": False})
                self.assertEqual(r.returncode, 2)

    # --- Loop-break (the fix for multi-agent handoff) ---

    def test_stop_hook_active_writes_aborted_and_exits_0(self):
        r = self.run_hook({"stop_hook_active": True})
        self.assertEqual(r.returncode, 0)
        state = json.loads((self.project_dir / ".plan-and-execute.state.json").read_text())
        self.assertEqual(state["status"], "aborted_by_phase_guard")

    def test_stop_hook_active_when_already_aborted_exits_0(self):
        self.write_state(run_id="run-123", phase=5, status="aborted_by_phase_guard")
        r = self.run_hook({"stop_hook_active": True})
        self.assertEqual(r.returncode, 0)
        state = json.loads((self.project_dir / ".plan-and-execute.state.json").read_text())
        self.assertEqual(state["status"], "aborted_by_phase_guard")

    # --- Awaiting-user sentinel ---

    def test_valid_sentinel_exits_0_and_is_consumed(self):
        self.write_sentinel()
        r = self.run_hook({"session_id": "sess-1", "stop_hook_active": False})
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.claude_dir / "awaiting-user").exists())

    def test_valid_sentinel_writes_grace_receipt(self):
        self.write_sentinel()
        self.run_hook({"session_id": "sess-1", "stop_hook_active": False})
        self.assertTrue((self.claude_dir / "awaiting-user-grace.json").exists())

    def test_sentinel_wrong_run_id_is_discarded_and_blocks(self):
        self.write_sentinel(run_id="run-other")
        r = self.run_hook({"session_id": "sess-1", "stop_hook_active": False})
        self.assertEqual(r.returncode, 2)
        self.assertFalse((self.claude_dir / "awaiting-user").exists())

    def test_sentinel_missing_reason_is_invalid_and_blocks(self):
        (self.claude_dir / "awaiting-user").write_text(
            json.dumps({"run_id": "run-123", "phase": 5})
        )
        r = self.run_hook({"stop_hook_active": False})
        self.assertEqual(r.returncode, 2)

    # --- Grace receipt ---

    def test_grace_receipt_honored_on_stop_hook_active(self):
        self.write_sentinel()
        self.run_hook({"session_id": "sess-1", "stop_hook_active": False})
        r = self.run_hook({"session_id": "sess-1", "stop_hook_active": True})
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.claude_dir / "awaiting-user-grace.json").exists())

    def test_expired_grace_receipt_causes_loop_break(self):
        # Expired grace is not honored; the loop-break still fires since stop_hook_active=True.
        (self.claude_dir / "awaiting-user-grace.json").write_text(
            json.dumps({"run_id": "run-123", "phase": 5, "expires_at": 1.0})
        )
        r = self.run_hook({"session_id": "sess-1", "stop_hook_active": True})
        self.assertEqual(r.returncode, 0)
        state = json.loads((self.project_dir / ".plan-and-execute.state.json").read_text())
        self.assertEqual(state["status"], "aborted_by_phase_guard")

    def test_grace_receipt_any_session_honored_within_ttl(self):
        # Grace receipt has no session scope — any session can consume it while valid.
        (self.claude_dir / "awaiting-user-grace.json").write_text(
            json.dumps({"run_id": "run-123", "phase": 5, "expires_at": time.time() + 120})
        )
        r = self.run_hook({"session_id": "sess-other", "stop_hook_active": True})
        self.assertEqual(r.returncode, 0)
        self.assertFalse((self.claude_dir / "awaiting-user-grace.json").exists())

    def test_new_session_after_sentinel_blocks(self):
        self.write_sentinel()
        self.run_hook({"session_id": "sess-1", "stop_hook_active": False})
        (self.claude_dir / "awaiting-user-grace.json").unlink()
        r = self.run_hook({"session_id": "sess-2", "stop_hook_active": False})
        self.assertEqual(r.returncode, 2)


if __name__ == "__main__":
    unittest.main()
