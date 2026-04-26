import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
INSTALL_SCRIPT = REPO_ROOT / "install.sh"
TEST_TMP_ROOT = REPO_ROOT / ".tmp-test-work"


class InstallScriptTest(unittest.TestCase):
    def setUp(self):
        TEST_TMP_ROOT.mkdir(parents=True, exist_ok=True)
        self.tempdir = tempfile.TemporaryDirectory(dir=TEST_TMP_ROOT)
        self.target = Path(self.tempdir.name) / "target"
        (self.target / ".claude" / "hooks").mkdir(parents=True, exist_ok=True)

    def tearDown(self):
        self.tempdir.cleanup()

    def run_install(self):
        return subprocess.run(
            ["bash", str(INSTALL_SCRIPT), str(self.target)],
            input="n\n",
            text=True,
            capture_output=True,
            check=False,
        )

    def settings(self):
        return json.loads((self.target / ".claude" / "settings.json").read_text())

    def stop_commands(self, data=None):
        data = data or self.settings()
        return [
            h["command"]
            for entry in data.get("hooks", {}).get("Stop", [])
            for h in (entry.get("hooks") or [])
            if isinstance(h, dict) and "command" in h
        ]

    # --- Basic registration ---

    def test_basic_install_registers_all_three_hooks(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        s = self.settings()
        self.assertIn(".claude/hooks/phase_guard.sh",
                      [h["command"] for entry in s["hooks"]["Stop"]
                       for h in entry.get("hooks", []) if isinstance(h, dict)])
        self.assertIn(".claude/hooks/block_sensitive_files.sh",
                      [h["command"] for entry in s["hooks"]["PreToolUse"]
                       for h in entry.get("hooks", []) if isinstance(h, dict)])
        self.assertIn(".claude/hooks/python_post_edit.sh",
                      [h["command"] for entry in s["hooks"]["PostToolUse"]
                       for h in entry.get("hooks", []) if isinstance(h, dict)])

    def test_no_double_register_on_reinstall(self):
        self.run_install()
        self.run_install()
        phase_guard_cmds = [c for c in self.stop_commands() if "phase_guard.sh" in c]
        self.assertEqual(len(phase_guard_cmds), 1,
                         f"phase_guard.sh must appear exactly once: {phase_guard_cmds}")

    def test_existing_hook_path_variant_not_double_registered(self):
        # If settings.json already contains any command with "phase_guard.sh" in it
        # (e.g. the skill-bundled path), install must not append a second entry.
        (self.target / ".claude" / "settings.json").write_text(json.dumps({
            "hooks": {
                "Stop": [{"matcher": "", "hooks": [
                    {"type": "command",
                     "command": "bash .claude/skills/plan-and-execute/hooks/phase_guard.sh",
                     "timeout": 10}
                ]}],
                "PreToolUse": [],
                "PostToolUse": [],
            }
        }))
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        phase_guard_cmds = [c for c in self.stop_commands() if "phase_guard.sh" in c]
        self.assertEqual(len(phase_guard_cmds), 1,
                         f"must not add a second phase_guard entry: {phase_guard_cmds}")

    def test_hooks_non_dict_does_not_crash(self):
        for bad in ({}, "disabled", 42):
            with self.subTest(hooks=bad):
                (self.target / ".claude" / "settings.json").write_text(
                    json.dumps({"hooks": bad})
                )
                result = self.run_install()
                self.assertNotIn("AttributeError", result.stdout + result.stderr)
                self.assertIn(result.returncode, (0, 1))

    # --- Legacy phase_guard.py removal ---

    def test_removes_legacy_phase_guard_py_on_success(self):
        legacy = self.target / ".claude" / "hooks" / "phase_guard.py"
        legacy.write_text("# legacy\n")
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(legacy.exists())

    def test_legacy_stop_entry_removed_from_settings_json(self):
        (self.target / ".claude" / "settings.json").write_text(json.dumps({
            "hooks": {"Stop": [{"matcher": "", "hooks": [
                {"type": "command", "command": "python3 .claude/hooks/phase_guard.py"}
            ]}]}
        }))
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        cmds = self.stop_commands()
        self.assertNotIn("python3 .claude/hooks/phase_guard.py", cmds)
        self.assertIn(".claude/hooks/phase_guard.sh", cmds)

    # --- Transactional safety ---

    def test_aborts_when_hook_destination_is_directory(self):
        bad_dest = self.target / ".claude" / "hooks" / "phase_guard.sh"
        bad_dest.mkdir()
        result = self.run_install()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("exists but is not a regular file", result.stdout)
        self.assertFalse((self.target / ".claude" / "settings.json").exists(),
                         "settings.json must not be written after preflight failure")

    def test_aborts_when_hooks_dir_not_writable(self):
        hooks_dir = self.target / ".claude" / "hooks"
        original_mode = hooks_dir.stat().st_mode
        try:
            os.chmod(hooks_dir, 0o555)
            result = self.run_install()
        finally:
            os.chmod(hooks_dir, original_mode)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.target / ".claude" / "settings.json").exists(),
                         "settings.json must not be written when hooks dir is unwritable")

    def test_staged_files_cleaned_up_on_migration_failure(self):
        # Make settings.json a directory so atomic_write_json fails → EXIT trap fires.
        settings_path = self.target / ".claude" / "settings.json"
        settings_path.mkdir()
        try:
            result = self.run_install()
        finally:
            if settings_path.is_dir():
                settings_path.rmdir()
        hooks_dir = self.target / ".claude" / "hooks"
        staged = list(hooks_dir.glob("*.installing.*"))
        self.assertEqual(staged, [],
                         f"staged temp files must be cleaned up on failure: {staged}")


if __name__ == "__main__":
    unittest.main()
