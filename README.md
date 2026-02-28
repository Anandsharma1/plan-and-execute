# plan-and-execute

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A unified lifecycle orchestrator for multi-step development -- research, plan, execute, review, finalize -- with persistent context and two-stage review.

---

## Features

- **7-phase lifecycle** -- Concept, Research, Plan, Tasks, Execute, Finalize -- with clear entry/exit criteria and tracked state across every phase
- **Two-stage review per task** -- spec compliance review followed by code quality review, both dispatched as fresh adversarial agents
- **Review learnings feedback loop** -- user-reported gaps and auto-detected patterns accumulate in `review-learnings.md` and feed into subsequent reviews
- **Persistent context files survive session resets** -- `task_plan.md`, `findings.md`, `progress.md`, and `review-learnings.md` are written to disk, not held in memory
- **RALPH-validated execution with convergence loop** -- optional integration with `ralph-loop` for iterative self-correction on convergence-heavy tasks
- **Topology-aware dispatch** -- Single Agent, Coordinated Sub-Agents, or Agent Team, chosen per plan based on blast radius, workstream count, and context pressure
- **Cross-platform** -- works with Claude Code, GitHub Copilot, Cursor, and Codex CLI
- **Strong anti-mocking stance** -- tests must verify real behavior, not mock calls; reviewers enforce this during code quality review

---

## Quick Start

Install as a Claude Code plugin:

```bash
claude plugin add Anandsharma1/plan-and-execute
claude plugin enable plan-and-execute
claude
```

Then invoke:

```
/plan-and-execute "Add user authentication"
```

---

## Installation

### Claude Code (Plugin Marketplace)

```
/plugin marketplace add Anandsharma1/plan-and-execute
```

### GitHub Copilot

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git .github/skills/plan-and-execute
```

### Cursor

1. Open **Settings** -> **Rules** -> **Remote Rule**
2. Add the GitHub URL: `https://github.com/Anandsharma1/plan-and-execute`

### Codex CLI

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git ~/.agents/skills/plan-and-execute
```

### SkillKit (Universal)

```bash
skillkit install github.com/Anandsharma1/plan-and-execute
```

### Manual

Clone the repository and copy its contents to your platform's skill directory:

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git
cp -r plan-and-execute/ <your-platform-skill-directory>/plan-and-execute/
```

---

## Project Setup

On first invocation, plan-and-execute detects that setup hasn't been completed and offers to run it automatically. Setup auto-detects your package manager, test runner, linter, and security scanner from the codebase, asks 2-3 questions (domain name, domain reviewer, logging preset), and generates all required config files. It never overwrites existing files.

**Generated files:**

| File | Purpose |
|------|---------|
| `.claude/project-config.yaml` | Parameter defaults (test/lint/security commands, logging policy) |
| `docs/review-standards.md` | Review criteria for two-stage review -- customize sections 2 and 5 for your domain |
| `docs/env-config-policy.md` | Environment and configuration rules -- review for your stack |
| `.claude/agents/<name>-reviewer.md` | Domain-specific reviewer agent (optional) -- fill in domain review criteria |
| `logging_config.py` | Python logging configuration (if logging preset chosen) |

To re-run setup later, delete `.claude/.plan-and-execute-setup.done` and invoke the skill again.

**Alternative:** Use the shell-based installer for non-interactive environments:

```bash
./install.sh /path/to/project
```

---

## Dependencies

plan-and-execute is an **orchestrator** -- it delegates to other skills at specific phases but does not reimplement their functionality. All dependencies are optional; the skill degrades gracefully when a dependency is unavailable.

| Dependency | Required? | What happens if missing |
|---|---|---|
| **planning-with-files** | Strongly recommended | Lose automatic `task_plan.md` context injection and session-catchup. Manual recovery still works via git and file reads. |
| **ralph-loop** | Optional | Run the validation suite manually (tests, lint, quality review) without the convergence loop. |
| **superpowers** | Optional | Phase 1: skip brainstorming path or do it manually. Phase 5: dispatch subagents directly. Phase 6: create PR manually. |
| **speckit** | Optional | Use the manual task breakdown path instead -- plan-and-execute provides its own lightweight task format as a fallback. |
| **claude-md-management** | Optional | Skip automatic CLAUDE.md revision; update manually if needed. |
| **Domain reviewer agent** | Optional | Domain-specific review in Phase 6 is skipped entirely. Set the `DOMAIN_REVIEWER` parameter to enable. |

---

## Usage

```
/plan-and-execute "Add user authentication"
/plan-and-execute "Fix login bug" CONCEPT_MODE=skip
/plan-and-execute "Refactor auth module" MODULE_NAME=auth
/plan-and-execute --help
```

The description is passed directly into the Goal field of `task_plan.md`. Parameters not provided at invocation use their defaults. Use `.claude/project-config.yaml` to set project-wide defaults.

### Standalone Domain Review

Review code against your project's standards without running the full lifecycle:

```
/domain-code-review                           # Review working tree changes
/domain-code-review abc123..def456            # Review commit range
```

This is the same project-specific review that runs during plan-and-execute Phase 5/6, but available independently.

---

## Phase Overview

| Phase | Name | Goal | Output |
|-------|------|------|--------|
| 0 | Initialize | Conflict check, resolve config, create tracking files | `task_plan.md`, `findings.md`, `progress.md`, `review-learnings.md` |
| 1 | Concept & Design | Explore intent via brainstorming, spec, or both | Design doc and/or `spec.md` (or skip if scope is clear) |
| 2 | Research | Codebase exploration with 2-action write rule | `findings.md` populated with discoveries, blast radius, open questions |
| 3 | Plan Generation | Formal plan with 7-dimension critical analysis | Approved plan file in `docs/plans/` |
| 4 | Task Breakdown | Decompose approved plan into atomic tasks | Tasks appended to the approved plan file |
| 5 | Execution | SDD dispatch per topology with two-stage review | Implemented code, commits, `review-learnings.md` updated |
| 6 | Finalization | Security scan, config check, domain review, documentation gates | Final summary, branch ready for PR |

---

## License

[MIT](LICENSE)
