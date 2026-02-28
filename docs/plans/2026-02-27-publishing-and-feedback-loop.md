# plan-and-execute Publishing & Review Learnings Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add a review-learnings feedback loop to the plan-and-execute skill, then restructure the repo for cross-platform publishing as a Claude Code plugin + universal Agent Skill.

**Architecture:** Three groups of changes: (1) new `review-learnings-template.md` file + SKILL.md edits for the feedback loop, (2) new repo scaffolding files (plugin.json, README, LICENSE, .gitignore, install.sh, settings.json), (3) git initialization. All work happens in `/home/anand.sharma/Documents/Learning/Projects/AI/Tooling/plan-and-execute/`.

**Tech Stack:** Markdown, YAML frontmatter, bash, git

---

## Task 1: Create review-learnings-template.md

**Files:**
- Create: `review-learnings-template.md`

**Step 1: Create the template file**

```markdown
# Review Learnings

Accumulated review patterns for this project. Created by plan-and-execute Phase 0.
Reviewers: load this file before each review dispatch and apply applicable instructions.

## User-Reported Gaps
<!-- Patterns identified by the user during Phase 5 execution.
     Format:
     ### [UG-N] <pattern name>
     - **Source:** User feedback during Task T-X
     - **What was missed:** <description>
     - **Review instruction:** <what reviewers should check for>
     - **Applies to:** spec-reviewer | code-quality-reviewer | both
-->

## Auto-Detected Patterns
<!-- Patterns found by reviewers in 2+ tasks.
     Format:
     ### [AD-N] <pattern name>
     - **Source:** Auto-detected across tasks T-X, T-Y
     - **Issue type:** <category>
     - **Review instruction:** <what to check>
     - **Applies to:** spec-reviewer | code-quality-reviewer | both
-->

## Promoted to Review Standards
<!-- Patterns promoted to docs/review-standards.md (audit trail).
     Format:
     ### [UG-N] or [AD-N] <pattern name> — promoted YYYY-MM-DD
-->
```

**Step 2: Verify the file exists**

Run: `ls -la review-learnings-template.md`
Expected: File exists with correct size

**Step 3: Commit**

```bash
git add review-learnings-template.md
git commit -m "feat: add review-learnings template for feedback loop"
```

---

## Task 2: Update SKILL.md — Prompt Templates table

**Files:**
- Modify: `SKILL.md:134-151` (Prompt Templates & Supporting Files section)

**Step 1: Add review-learnings-template.md to the Prompt Templates table**

In the `## Prompt Templates & Supporting Files` section (line 134), add a new row to the first table after the `task-plan-template.md` row (line 142):

```markdown
| `./review-learnings-template.md` | Phase 0 | Starter review-learnings.md — accumulated review patterns during execution |
```

And add a new row to the Bootstrap Templates table after the `domain-reviewer-template.md` row (line 150):

```markdown
| `./templates/project-config-example.yaml` | Starter project-config.yaml — parameter defaults per project |
```

Wait — the project-config-example.yaml is already in templates/ but not listed. Only add the review-learnings entry.

**Step 2: Verify the table renders correctly**

Read back lines 134-155 to confirm the table is well-formed.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "docs: add review-learnings-template to prompt templates table"
```

---

## Task 3: Update SKILL.md — Phase 0 (add review-learnings.md to tracking files)

**Files:**
- Modify: `SKILL.md:209-216` (Phase 0, Initialize files section)

**Step 1: Add review-learnings.md creation to Phase 0 init**

After line 215 (`findings.md` and `progress.md` as created by the plugin are used as-is.), add:

```markdown

3. Create `${CONTEXT_DIR}/review-learnings.md` from `./review-learnings-template.md`. This file accumulates review patterns during Phase 5 execution (user-reported gaps + auto-detected patterns). Reviewers load it before each dispatch.
```

**Step 2: Update the Architecture table**

In the "Each file has ONE job" table (lines 116-122), add a new row after `progress.md`:

```markdown
| `review-learnings.md` | Accumulated review patterns (user-reported gaps + auto-detected) | Phase 5 (execution), Phase 6 (promotion) |
```

**Step 3: Verify changes read correctly**

Read back the modified sections.

**Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat: add review-learnings.md initialization to Phase 0"
```

---

## Task 4: Update SKILL.md — Phase 5 (User Feedback Capture rule)

**Files:**
- Modify: `SKILL.md:518-521` (Phase 5, Topology A Rules section)

**Step 1: Add User Feedback Capture and Auto-Pattern Detection rules**

After the existing rules block (lines 518-521), add:

```markdown

   **User Feedback Capture:**
   If the user identifies a gap during execution (e.g., "you missed error handling for X", "this edge case wasn't caught"), immediately:
   1. Extract the pattern: what was missed, what type of review should have caught it
   2. Append to `${CONTEXT_DIR}/review-learnings.md` under `## User-Reported Gaps`:
      ```markdown
      ### [UG-N] <pattern name>
      - **Source:** User feedback during Task T-X
      - **What was missed:** <description>
      - **Review instruction:** <what reviewers should check for>
      - **Applies to:** spec-reviewer | code-quality-reviewer | both
      ```
   3. All subsequent reviewer dispatches in the current session must load `review-learnings.md`

   **Auto-Pattern Detection:**
   After each spec-reviewer or code-quality-reviewer completes, check:
   - Has the same category of issue appeared in 2+ different tasks? (e.g., "missing input validation" flagged in T-2 and T-5)
   - If yes, append to `${CONTEXT_DIR}/review-learnings.md` under `## Auto-Detected Patterns`:
      ```markdown
      ### [AD-N] <pattern name>
      - **Source:** Auto-detected across tasks T-X, T-Y
      - **Issue type:** <category>
      - **Review instruction:** <what to check>
      - **Applies to:** spec-reviewer | code-quality-reviewer | both
      ```
   - Deduplicate: before adding, check if the pattern already exists in review-learnings.md
```

**Step 2: Add reviewer loading instruction to the Prompt Templates note**

After line 516 (the prompt templates list), add:

```markdown
   - If `${CONTEXT_DIR}/review-learnings.md` exists, include it in the reviewer dispatch prompt with instruction: "Apply any review instructions from entries applicable to your role."
```

**Step 3: Verify changes**

Read back the modified section.

**Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat: add user feedback capture and auto-pattern detection to Phase 5"
```

---

## Task 5: Update SKILL.md — Phase 6 (promotion logic)

**Files:**
- Modify: `SKILL.md:684-697` (Phase 6, step 5 — consolidate review findings)

**Step 1: Extend the consolidation step with promotion logic**

After the existing consolidation table (line 696), add:

```markdown

   **Promotion from review-learnings.md:**
   After classifying Phase 5 findings above, also process `${CONTEXT_DIR}/review-learnings.md`:
   - Entries (UG or AD) with 3+ task occurrences → promote to `${REVIEW_STANDARDS}` as a permanent review check
   - Move promoted entries to `## Promoted to Review Standards` section in review-learnings.md (do not delete — audit trail):
     ```markdown
     ### [UG-N] <pattern name> — promoted YYYY-MM-DD
     ```
   - Reviewer blind spots identified via auto-detection → amend `./code-quality-reviewer-prompt.md` or `./spec-reviewer-prompt.md` as appropriate
```

**Step 2: Verify changes**

Read back lines 684-710 to confirm the section flows correctly.

**Step 3: Commit**

```bash
git add SKILL.md
git commit -m "feat: add review-learnings promotion logic to Phase 6"
```

---

## Task 6: Create .claude-plugin/plugin.json

**Files:**
- Create: `.claude-plugin/plugin.json`

**Step 1: Create the directory and manifest**

```bash
mkdir -p .claude-plugin
```

```json
{
  "name": "plan-and-execute",
  "description": "Unified lifecycle orchestrator for multi-step development: 7-phase planning, two-stage review, persistent context, RALPH-validated execution",
  "version": "1.0.0",
  "author": {
    "name": "Anand Sharma"
  },
  "license": "MIT"
}
```

**Step 2: Verify**

Run: `cat .claude-plugin/plugin.json | python3 -m json.tool`
Expected: Valid JSON output

**Step 3: Commit**

```bash
git add .claude-plugin/plugin.json
git commit -m "feat: add Claude Code plugin manifest"
```

---

## Task 7: Create LICENSE

**Files:**
- Create: `LICENSE`

**Step 1: Create MIT license**

Standard MIT license text with current year and author name.

**Step 2: Commit**

```bash
git add LICENSE
git commit -m "docs: add MIT license"
```

---

## Task 8: Create .gitignore

**Files:**
- Create: `.gitignore`

**Step 1: Create .gitignore**

```
settings.local.json
```

Only exclude the project-specific settings file. Everything else should be tracked.

**Step 2: Commit**

```bash
git add .gitignore
git commit -m "chore: add .gitignore"
```

---

## Task 9: Create settings.json (plugin-level defaults)

**Files:**
- Create: `settings.json`
- Note: `settings.local.json` stays in `.gitignore` for local overrides

**Step 1: Create plugin settings**

```json
{
  "permissions": {
    "allow": [
      "Read(**)"
    ]
  }
}
```

Minimal — allows the skill to read files in any project. Project-specific permissions go in `settings.local.json` (gitignored).

**Step 2: Commit**

```bash
git add settings.json
git commit -m "feat: add plugin-level default settings"
```

---

## Task 10: Create install.sh

**Files:**
- Create: `install.sh`

**Step 1: Write the bootstrap script**

```bash
#!/bin/bash
set -euo pipefail

# Usage: ./install.sh /path/to/your/project
# Copies plan-and-execute templates to a target project for customization.
# Safe to re-run — never overwrites existing files.

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-.}"

if [ ! -d "$TARGET" ]; then
  echo "Error: Target directory '$TARGET' does not exist."
  exit 1
fi

copy_if_missing() {
  local src="$1" dest="$2"
  if [ -f "$dest" ]; then
    echo "  SKIP (exists): $dest"
  else
    mkdir -p "$(dirname "$dest")"
    cp "$src" "$dest"
    echo "  CREATED: $dest"
  fi
}

echo "Bootstrapping plan-and-execute templates into: $TARGET"
echo ""

copy_if_missing "$SCRIPT_DIR/templates/review-standards-template.md" "$TARGET/docs/review-standards.md"
copy_if_missing "$SCRIPT_DIR/templates/env-config-policy-template.md" "$TARGET/docs/env-config-policy.md"
copy_if_missing "$SCRIPT_DIR/templates/domain-reviewer-template.md" "$TARGET/.claude/agents/domain-reviewer.md"
copy_if_missing "$SCRIPT_DIR/templates/project-config-example.yaml" "$TARGET/.claude/project-config.yaml"

echo ""
echo "Done. Next steps:"
echo "  1. Edit docs/review-standards.md — customize sections 1-5 for your domain"
echo "  2. Edit docs/env-config-policy.md — adjust rules for your stack"
echo "  3. Edit .claude/agents/domain-reviewer.md — fill in domain-specific review criteria"
echo "  4. Edit .claude/project-config.yaml — set your test/lint/security commands"
echo ""
echo "See HELP.md for full usage instructions."
```

**Step 2: Make executable**

Run: `chmod +x install.sh`

**Step 3: Verify**

Run: `./install.sh --help 2>&1 || true`
Expected: Script runs without syntax errors

**Step 4: Commit**

```bash
git add install.sh
git commit -m "feat: add project bootstrap script"
```

---

## Task 11: Create README.md

**Files:**
- Create: `README.md`

**Step 1: Write the README**

Include these sections:
1. **Title** — `# plan-and-execute`
2. **Badges** — license (MIT)
3. **One-liner** — Unified lifecycle orchestrator for multi-step development work
4. **Features** — bullet list: 7-phase lifecycle, two-stage review (spec + code quality), review learnings feedback loop, persistent context (crash-resistant), RALPH-validated execution, topology-aware dispatch (single agent / sub-agents / agent team), cross-platform (Claude Code, Copilot, Cursor, Codex)
5. **Quick Start** — 3 commands for Claude Code plugin install
6. **Installation** — platform-specific sections:
   - Claude Code (plugin marketplace)
   - GitHub Copilot (clone to `.github/skills/`)
   - Cursor (Settings → Remote Rule with GitHub URL)
   - Codex CLI (clone to `~/.agents/skills/`)
   - SkillKit (universal: `skillkit install`)
   - Manual (any platform: clone + copy)
7. **Project Setup** — `./install.sh /path/to/project` + what each template does
8. **Dependencies** — table: planning-with-files (strongly recommended), ralph-loop, superpowers, speckit, claude-md-management, domain-reviewer (all optional with fallback behavior)
9. **Usage** — invocation examples with parameters
10. **Phase Overview** — 7-phase table (Phase 0-6, each with goal + output)
11. **License** — MIT

**Step 2: Verify**

Read back the file to check formatting.

**Step 3: Commit**

```bash
git add README.md
git commit -m "docs: add README with cross-platform installation instructions"
```

---

## Task 12: Initialize git repo and prepare for GitHub

**Files:**
- No files created — git operations only

**Step 1: Initialize git repo**

Run from `/home/anand.sharma/Documents/Learning/Projects/AI/Tooling/plan-and-execute/`:

```bash
git init
```

**Step 2: Stage all files**

```bash
git add -A
```

**Step 3: Verify .gitignore works**

Run: `git status`
Expected: `settings.local.json` is NOT listed in staged files

**Step 4: Create initial commit**

```bash
git commit -m "feat: plan-and-execute skill — unified lifecycle orchestrator for multi-step development

7-phase lifecycle with persistent context, two-stage review,
review learnings feedback loop, and RALPH-validated execution.

Cross-platform: Claude Code, GitHub Copilot, Cursor, Codex CLI."
```

**Step 5: Verify**

Run: `git log --oneline`
Expected: Single commit with the message above

---

## Task 13: Final verification

**Step 1: Verify repo structure**

Run: `find . -not -path './.git/*' -not -path './.git' | sort`

Expected output should match the planned structure:
```
.
./.claude-plugin
./.claude-plugin/plugin.json
./.gitignore
./agent-spec-reviewer-prompt.md
./code-quality-reviewer-prompt.md
./docs
./docs/plans
./docs/plans/2026-02-27-publishing-and-feedback-loop-design.md
./docs/plans/2026-02-27-publishing-and-feedback-loop.md
./HELP.md
./implementer-prompt.md
./install.sh
./LICENSE
./README.md
./review-learnings-template.md
./settings.json
./settings.local.json
./SKILL.md
./spec-reviewer-prompt.md
./task-plan-template.md
./templates
./templates/domain-reviewer-template.md
./templates/env-config-policy-template.md
./templates/project-config-example.yaml
./templates/review-standards-template.md
```

**Step 2: Verify SKILL.md changes are coherent**

Read SKILL.md and check:
- Phase 0 mentions review-learnings.md creation
- Phase 5 has User Feedback Capture and Auto-Pattern Detection rules
- Phase 5 reviewer dispatch includes review-learnings.md loading
- Phase 6 has promotion logic
- Prompt Templates table includes review-learnings-template.md
- Architecture table includes review-learnings.md

**Step 3: Done**

Report: repo is ready for `git remote add origin` and `git push`.
