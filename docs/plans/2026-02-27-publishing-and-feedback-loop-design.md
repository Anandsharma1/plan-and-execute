# Design: plan-and-execute Publishing & Review Learnings Feedback Loop

**Date:** 2026-02-27
**Status:** Approved

---

## 1. Problem Statement

The plan-and-execute skill needs three enhancements:

1. **Review Learnings Feedback Loop** — No mechanism exists to capture user-identified gaps or auto-detected patterns during Phase 5 execution and feed them to subsequent reviewer dispatches
2. **GitHub Publishing** — The skill exists as a local directory; it needs to be publishable as a standalone GitHub repo that works across all major AI coding platforms
3. **Repo Structure** — LICENSE, README, install script, plugin manifest for Claude Code, and cross-platform compatibility

---

## 2. Design: Review Learnings Feedback Loop

### 2.1 New File: `review-learnings.md`

Created in Phase 0 alongside `task_plan.md`, `findings.md`, `progress.md`. Starts with this structure:

```markdown
# Review Learnings

## User-Reported Gaps

## Auto-Detected Patterns

## Promoted to Review Standards
```

A template file `review-learnings-template.md` ships with the skill.

### 2.2 Input Trigger 1: User-Reported Gap

When a user identifies something missed during Phase 5 (e.g., "you missed error handling for X"), the orchestrator:

1. Extracts the pattern (what was missed, what should have caught it)
2. Appends to `## User-Reported Gaps`:

```markdown
### [UG-N] <pattern name>
- **Source:** User feedback during Task T-X
- **What was missed:** <description>
- **Review instruction:** <what reviewers should check for>
- **Applies to:** spec-reviewer | code-quality-reviewer | both
```

3. All subsequent reviewer dispatches in the same session load `review-learnings.md`

### 2.3 Input Trigger 2: Auto-Detected Pattern

After each code-quality or spec review completes, the orchestrator checks:
- Has the same category of issue (e.g., "missing input validation", "no error handling for API calls") appeared in 2+ different tasks?
- If yes, append to `## Auto-Detected Patterns`:

```markdown
### [AD-N] <pattern name>
- **Source:** Auto-detected across tasks T-X, T-Y
- **Issue type:** <category>
- **Review instruction:** <what to check>
- **Applies to:** spec-reviewer | code-quality-reviewer | both
```

### 2.4 How Reviewers Consume It

Both `spec-reviewer-prompt.md` and `code-quality-reviewer-prompt.md` get an additional instruction block in the orchestrator's dispatch:

```
If review-learnings.md exists at ${CONTEXT_DIR}/review-learnings.md, read it before reviewing.
Apply any review instructions from entries marked as applicable to your role.
```

### 2.5 Phase 6 Promotion

The existing Phase 6 consolidation step (step 4 in Finalization) gets extended:

- Patterns with 3+ occurrences across tasks → promoted to `docs/review-standards.md`
- Promoted entries marked in `## Promoted to Review Standards` section (not deleted — audit trail)
- Reviewer blind spots (auto-detected patterns the reviewer should have caught) → amend the relevant reviewer prompt template

### 2.6 Changes to SKILL.md

| Location | Change |
|---|---|
| Phase 0 | Add `review-learnings.md` to tracking files list |
| Phase 5 (execution rules) | Add "User Feedback Capture" rule |
| Phase 5 (execution rules) | Add "Auto-Pattern Detection" rule (check after each review) |
| Phase 5 (reviewer dispatch) | Add instruction to load `review-learnings.md` |
| Phase 6 (consolidation) | Extend with promotion logic (3+ occurrences → review-standards) |

---

## 3. Design: Cross-Platform Publishing

### 3.1 Platform Compatibility

The Agent Skills standard (`SKILL.md` with YAML frontmatter) is supported by:

| Platform | Skill Directory | Installation |
|---|---|---|
| Claude Code | `~/.claude/skills/` or plugin marketplace | `/plugin marketplace add` |
| GitHub Copilot | `.github/skills/` or `~/.copilot/skills/` | Copy skill directory |
| Cursor | `.cursor/skills/` or `.agents/skills/` | Settings → Remote Rule (GitHub URL) |
| Codex CLI | `~/.agents/skills/` or `.agents/skills/` | Built-in installer or manual copy |
| Universal | `.agents/skills/` | Clone repo |

Cross-platform tools: SkillKit (`skillkit install <repo>`), skills.sh (Vercel directory), agent-skills-cli.

### 3.2 Repo Structure

```
plan-and-execute/                        ← GitHub repo root = skill folder
├── SKILL.md                             # Main skill (at root for universal compat)
├── HELP.md                              # User-facing help
├── .claude-plugin/
│   └── plugin.json                      # Claude Code plugin manifest
├── README.md                            # GitHub-facing documentation
├── LICENSE                              # MIT
├── .gitignore                           # Exclude settings.local.json
├── implementer-prompt.md                # Subagent: implementation
├── spec-reviewer-prompt.md              # Subagent: spec compliance review
├── agent-spec-reviewer-prompt.md        # Subagent: agent-level spec review (Topology C)
├── code-quality-reviewer-prompt.md      # Subagent: code quality review
├── task-plan-template.md                # Template: meta-tracker
├── review-learnings-template.md         # Template: review-learnings.md (NEW)
├── settings.json                        # Plugin-level default settings
├── install.sh                           # Project template bootstrap script
└── templates/
    ├── project-config-example.yaml      # Project config defaults
    ├── domain-reviewer-template.md      # Domain-specific reviewer agent
    ├── review-standards-template.md     # Review standards for project
    └── env-config-policy-template.md    # Environment/config policy
```

Key decision: **SKILL.md at repo root** so the repo itself IS the skill folder. Works natively with all platforms. `.claude-plugin/` adds Claude Code plugin metadata without breaking universal format.

### 3.3 plugin.json

```json
{
  "name": "plan-and-execute",
  "description": "Unified lifecycle orchestrator for multi-step development: 7-phase planning, two-stage review, persistent context, RALPH-validated execution",
  "version": "1.0.0",
  "author": {
    "name": "Anand Sharma"
  },
  "repository": "https://github.com/<user>/plan-and-execute",
  "license": "MIT"
}
```

### 3.4 install.sh

Bootstrap script that copies templates to a target project directory:

```bash
#!/bin/bash
# Usage: ./install.sh /path/to/your/project
# - Creates docs/ and .claude/agents/ if needed
# - Copies templates (review-standards, env-config-policy, domain-reviewer, project-config)
# - Does NOT overwrite existing files (safe to re-run)
# - Prints instructions for customizing each template
```

### 3.5 .gitignore

```
settings.local.json
```

### 3.6 README.md Structure

1. **Title + badges** (version, license, platforms)
2. **One-liner** — Unified lifecycle orchestrator for multi-step dev work
3. **Features** — 7-phase lifecycle, two-stage review, review learnings, persistent context, RALPH validation
4. **Quick Start** — 3 commands
5. **Installation** — platform-specific sections:
   - Universal (any Agent Skills-compatible platform)
   - Claude Code (plugin marketplace)
   - GitHub Copilot
   - Cursor
   - Codex CLI
   - SkillKit (auto-deploys to all)
6. **Project Setup** — bootstrap templates
7. **Dependencies** — required vs optional table with fallback behavior
8. **Usage & Parameters** — invocation examples
9. **Phase Overview** — concise 7-phase table
10. **License** — MIT

---

## 4. Implementation Plan

### 4.1 Review Learnings (SKILL.md changes)

1. Create `review-learnings-template.md`
2. Update SKILL.md Phase 0: add `review-learnings.md` to tracking files
3. Update SKILL.md Phase 5: add User Feedback Capture rule
4. Update SKILL.md Phase 5: add Auto-Pattern Detection rule
5. Update SKILL.md Phase 5: add reviewer dispatch instruction to load `review-learnings.md`
6. Update SKILL.md Phase 6: extend consolidation step with promotion logic

### 4.2 Repo Structure & Publishing

7. Create `.claude-plugin/plugin.json`
8. Create `README.md`
9. Create `LICENSE` (MIT)
10. Create `.gitignore`
11. Create `install.sh`
12. Rename `settings.local.json` → `settings.json` (remove project-specific content)
13. Initialize git repo, commit, and set up for GitHub push

---

## Sources

- [Agent Skills Standard](https://agentskills.io)
- [Claude Code Skills Docs](https://code.claude.com/docs/en/skills)
- [Claude Code Plugins Docs](https://code.claude.com/docs/en/plugins)
- [GitHub Copilot Agent Skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills)
- [Codex CLI Skills](https://developers.openai.com/codex/skills/)
- [Cursor Agent Skills](https://cursor.com/docs/context/skills)
- [SkillKit](https://github.com/rohitg00/skillkit)
- [Anthropic Skills Repo](https://github.com/anthropics/skills)
