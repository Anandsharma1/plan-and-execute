import os
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
SYNC_SCRIPT = REPO_ROOT / "scripts" / "sync-ide-folders.sh"
TEST_TMP_ROOT = REPO_ROOT / ".tmp-test-work"


REQUIRED_FILES = {
    "SKILL.md": "---\nname: plan-and-execute\ndescription: test\nuser-invokable: true\nargument-hint: test\n---\nbody\n",
    "implementer-prompt.md": "impl\n",
    "spec-reviewer-prompt.md": "spec\n",
    "agent-spec-reviewer-prompt.md": "agent\n",
    "code-quality-reviewer-prompt.md": "quality\n",
    "setup-prompt.md": "setup\n",
    "HELP.md": "help\n",
    "domain-code-review/SKILL.md": "domain review\n",
    "hooks/block_sensitive_files.sh": "#!/bin/bash\n",
    "hooks/python_post_edit.sh": "#!/bin/bash\n",
    "hooks/phase_guard.sh": "#!/bin/bash\n",
    "templates/example.txt": "template\n",
}

TARGETS = [
    ".claude/skills/plan-and-execute",
    ".cursor/skills/plan-and-execute",
    ".codex/skills/plan-and-execute",
    ".github/skills/plan-and-execute",
    ".gemini/skills/plan-and-execute",
    ".agents/skills/plan-and-execute",
]

SIBLINGS = [
    ".claude/skills/domain-code-review",
    ".cursor/skills/domain-code-review",
    ".codex/skills/domain-code-review",
    ".github/skills/domain-code-review",
    ".gemini/skills/domain-code-review",
    ".agents/skills/domain-code-review",
]


class SyncIdeFoldersTest(unittest.TestCase):
    def test_repo_bundled_phase_guard_matches_canonical_hook(self):
        canonical = (REPO_ROOT / "hooks" / "phase_guard.sh").read_text()
        bundled = (
            REPO_ROOT
            / ".claude"
            / "skills"
            / "plan-and-execute"
            / "hooks"
            / "phase_guard.sh"
        ).read_text()

        self.assertEqual(bundled, canonical)

    def setUp(self):
        TEST_TMP_ROOT.mkdir(parents=True, exist_ok=True)
        self.tempdir = tempfile.TemporaryDirectory(dir=TEST_TMP_ROOT)
        self.repo = Path(self.tempdir.name)
        script_dest = self.repo / "scripts" / "sync-ide-folders.sh"
        script_dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(SYNC_SCRIPT, script_dest)
        for rel_path, contents in REQUIRED_FILES.items():
            path = self.repo / rel_path
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(contents)
        for target in TARGETS + SIBLINGS:
            (self.repo / target).mkdir(parents=True, exist_ok=True)

        self.readonly_target = self.repo / ".codex" / "skills" / "plan-and-execute"
        self.original_mode = stat.S_IMODE(os.stat(self.readonly_target).st_mode)
        os.chmod(self.readonly_target, 0o555)

    def tearDown(self):
        os.chmod(self.readonly_target, self.original_mode)
        self.tempdir.cleanup()

    def run_sync(self, *args, env=None):
        return subprocess.run(
            ["bash", "scripts/sync-ide-folders.sh", *args],
            cwd=self.repo,
            text=True,
            capture_output=True,
            env=env,
            check=False,
        )

    def test_default_mode_fails_when_any_target_cannot_be_updated(self):
        result = self.run_sync()
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("Sync incomplete", result.stdout)
        self.assertFalse((self.repo / ".claude" / "skills" / "plan-and-execute" / "SKILL.md").exists())
        self.assertFalse((self.repo / ".cursor" / "skills" / "plan-and-execute" / "SKILL.md").exists())
        self.assertFalse((self.repo / ".github" / "skills" / "plan-and-execute" / "SKILL.md").exists())
        self.assertEqual(list(self.repo.rglob("*.tmp.*")), [])

    def test_best_effort_mode_reports_failures_but_returns_success(self):
        result = self.run_sync("--best-effort")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Done (best effort).", result.stdout)

    def test_best_effort_preserves_legacy_hook_when_phase_guard_copy_fails(self):
        legacy_hook = self.repo / ".claude" / "skills" / "plan-and-execute" / "hooks" / "phase_guard.py"
        legacy_hook.parent.mkdir(parents=True, exist_ok=True)
        legacy_hook.write_text("#!/bin/bash\n")
        os.chmod(self.repo / "hooks" / "phase_guard.sh", 0o000)

        result = self.run_sync("--best-effort")

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(legacy_hook.exists())
        self.assertIn("skipping legacy hook removal", result.stdout)

    def test_default_mode_rolls_back_committed_files_after_mid_commit_failure(self):
        os.chmod(self.readonly_target, self.original_mode)
        wrapper_dir = self.repo / "test-bin"
        wrapper_dir.mkdir(parents=True, exist_ok=True)
        mv_wrapper = wrapper_dir / "mv"
        real_mv = shutil.which("mv") or "/bin/mv"
        mv_wrapper.write_text(
            "#!/bin/bash\n"
            "set -e\n"
            "dest=\"${@: -1}\"\n"
            "if [ \"${SYNC_FAIL_DEST:-}\" = \"$dest\" ]; then\n"
            "  exit 1\n"
            "fi\n"
            f"exec {real_mv} \"$@\"\n"
        )
        os.chmod(mv_wrapper, 0o755)

        env = os.environ.copy()
        env["PATH"] = f"{wrapper_dir}:{env['PATH']}"
        env["SYNC_FAIL_DEST"] = ".github/skills/plan-and-execute/SKILL.md"

        result = self.run_sync(env=env)

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertFalse((self.repo / ".claude" / "skills" / "plan-and-execute" / "SKILL.md").exists())
        self.assertFalse((self.repo / ".cursor" / "skills" / "plan-and-execute" / "SKILL.md").exists())
        self.assertFalse((self.repo / ".github" / "skills" / "plan-and-execute" / "SKILL.md").exists())
        self.assertEqual(list(self.repo.rglob("*.tmp.*")), [])
        self.assertEqual(list(self.repo.rglob("*.rollback.*")), [])


    def test_default_mode_rolls_back_committed_files_when_legacy_hook_deletion_fails(self):
        # If the post-commit legacy-hook deletion fails, the sync must roll back
        # all promoted bundle files so default mode stays fail-closed (no partial
        # release artifacts left behind).
        os.chmod(self.readonly_target, self.original_mode)

        # Create the legacy hook as a directory so `rm -f` is silently rejected.
        legacy_hook = (
            self.repo / ".claude" / "skills" / "plan-and-execute" / "hooks" / "phase_guard.py"
        )
        legacy_hook.mkdir(parents=True, exist_ok=True)

        result = self.run_sync()

        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        # The legacy "hook" (directory) still exists — deletion was blocked.
        self.assertTrue(legacy_hook.is_dir())
        # All committed bundle files must be rolled back.
        self.assertFalse(
            (self.repo / ".claude" / "skills" / "plan-and-execute" / "SKILL.md").exists()
        )
        self.assertFalse(
            (self.repo / ".cursor" / "skills" / "plan-and-execute" / "SKILL.md").exists()
        )
        # No leftover staging or rollback artifacts.
        self.assertEqual(list(self.repo.rglob("*.tmp.*")), [])
        self.assertEqual(list(self.repo.rglob("*.rollback.*")), [])


    def test_legacy_hook_removed_even_when_phase_guard_was_already_in_sync(self):
        # Regression: legacy .py hook must be deleted whenever the .sh replacement exists
        # at the target — regardless of whether phase_guard.sh was rewritten in this run.
        # Old code gated deletion on COMMITTED_DESTS, so a fresh sync where nothing changed
        # would silently preserve the deleted Python hook.
        os.chmod(self.readonly_target, self.original_mode)
        bundle_hooks_dir = self.repo / ".claude" / "skills" / "plan-and-execute" / "hooks"
        bundle_hooks_dir.mkdir(parents=True, exist_ok=True)

        # Pre-populate phase_guard.sh so it's already in sync (won't appear in COMMITTED_DESTS).
        import shutil as _shutil
        _shutil.copy(self.repo / "hooks" / "phase_guard.sh", bundle_hooks_dir / "phase_guard.sh")

        # Plant the legacy Python hook.
        legacy_hook = bundle_hooks_dir / "phase_guard.py"
        legacy_hook.write_text("#!/usr/bin/env python3\n")

        result = self.run_sync()

        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(legacy_hook.exists(), "legacy .py hook must be removed on every sync where .sh exists")


if __name__ == "__main__":
    unittest.main()
