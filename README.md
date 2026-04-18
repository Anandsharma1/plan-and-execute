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

The repo includes pre-built IDE directories so each platform picks up the skill automatically.

### Claude Code (Plugin Marketplace)

```
/plugin marketplace add Anandsharma1/plan-and-execute
```

### GitHub Copilot

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git
cp -r plan-and-execute/.github/skills/plan-and-execute/ .github/skills/plan-and-execute/
cp -r plan-and-execute/.github/skills/domain-code-review/ .github/skills/domain-code-review/
```

### Cursor

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git
cp -r plan-and-execute/.cursor/skills/plan-and-execute/ .cursor/skills/plan-and-execute/
cp -r plan-and-execute/.cursor/skills/domain-code-review/ .cursor/skills/domain-code-review/
```

### Codex CLI

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git
cp -r plan-and-execute/.codex/skills/plan-and-execute/ .codex/skills/plan-and-execute/
cp -r plan-and-execute/.codex/skills/domain-code-review/ .codex/skills/domain-code-review/
```

### Gemini CLI

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git
cp -r plan-and-execute/.gemini/skills/plan-and-execute/ .gemini/skills/plan-and-execute/
cp -r plan-and-execute/.gemini/skills/domain-code-review/ .gemini/skills/domain-code-review/
```

### SkillKit / npx (Universal)

```bash
npx skills add Anandsharma1/plan-and-execute
```

### Manual

```bash
git clone https://github.com/Anandsharma1/plan-and-execute.git
cp -r plan-and-execute/.agents/skills/plan-and-execute/ <your-platform-skill-directory>/plan-and-execute/
cp -r plan-and-execute/.agents/skills/domain-code-review/ <your-platform-skill-directory>/domain-code-review/
```

---

## How It Works: Generic Layer + Project Layer

plan-and-execute ships a **generic orchestration harness** that works out of the box. What makes reviews meaningful for your specific codebase is the **project layer** — a set of files you customize once and reuse across every feature.

```
Generic layer (ships with P&E, never edit)        Project layer (you own, fill in once)
─────────────────────────────────────────         ────────────────────────────────────
SKILL.md          — lifecycle orchestrator         docs/review-standards.md
HELP.md           — reference documentation         └─ Section 2: domain rules
hooks/phase_guard.sh — phase enforcement            └─ Section 5: invariants
templates/        — starter files for setup        .claude/agents/domain-reviewer.md
                                                    └─ domain-specific review criteria
                                                   .claude/shared/review-preamble.md
                                                    └─ top escape classes (≤20 lines)
                                                   .claude/project-config.yaml
                                                    └─ commands, thresholds, modes
                                                   CLAUDE.md (Agent Dispatch Discipline)
                                                    └─ incident-derived agent safety rules
```

The generic layer orchestrates. The project layer tells it what good looks like for your domain.

---

## Getting Started: Three Steps

### Step 1 — Install

```bash
./install.sh /path/to/your/project
```

Or on first invocation of `/plan-and-execute`, it offers to run setup automatically.

This generates the project-layer files from templates (never overwrites existing files):

| Generated file | What it does |
|---|---|
| `.claude/project-config.yaml` | Commands, thresholds, plug points — the harness configuration |
| `docs/review-standards.md` | Review rule library — fill in domain rules and invariants |
| `docs/env-config-policy.md` | Config/env boundary rules |
| `.claude/agents/domain-reviewer.md` | Domain reviewer agent — default-on during Phase 5/6 |
| `.claude/shared/review-preamble.md` | Short reviewer posture file — points to standards, inject escape classes |
| `CLAUDE.md` (appended) | Agent Dispatch Discipline block — incident-derived subagent safety rules |
| `logging_config.py` | Logging setup (if preset chosen) |

### Step 2 — Configure the project layer

The generated files have `<!-- CUSTOMIZE -->` markers where you add project-specific content. Instead of editing them manually, run the init skill:

```
/plan-and-execute-init
```

This walks you through each file interactively, asks about your domain and critical failure modes, and fills in the placeholder sections. It never overwrites content you've already written. Typical runtime: 5–10 minutes.

**What it asks:**
- What does your project do? (1–2 sentences)
- What are the 3–5 most expensive bugs in your codebase? (data loss, wrong outputs, security)

**What it fills in:**
- `review-standards.md` — layer mapping, domain-specific rules, invariants
- `domain-reviewer.md` — project name, domain review criteria
- `review-preamble.md` — top escape classes (brief pointers, not full rules)
- `project-config.yaml` — promotion thresholds, gate modes

To re-run a single file: `/plan-and-execute-init --file review-standards.md`

### Step 3 — Use

```
/plan-and-execute "Add user authentication"
```

---

## Project Setup (Manual / Non-interactive)

If you prefer manual setup or are configuring a non-interactive environment:

```bash
./install.sh /path/to/project
```

Then edit the generated files directly. Each has `<!-- CUSTOMIZE -->` markers showing exactly what needs project-specific content. See `HELP.md` for parameter reference.

To re-run setup later, delete `.claude/.plan-and-execute-setup.done` and invoke the skill again.
To disable the domain reviewer, set `DOMAIN_REVIEWER: "none"` in `.claude/project-config.yaml`.

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
| **Domain reviewer agent** | Default-on (recommended) | Uses `DOMAIN_REVIEWER=domain-reviewer` by default. If missing, the run flags it and recommends bootstrap. Disable manually with `DOMAIN_REVIEWER=none`. |

Missing dependency behavior:
- Missing optional dependency does not fail the run by itself.
- If a missing dependency is needed by a chosen path, plan-and-execute uses a documented fallback.
- Only fallback decisions are logged (missing + fallback, or missing + blocked); missing-but-unused dependencies are not logged to avoid noise.
- Domain reviewer is default-on: if `domain-reviewer` is missing, it is flagged in progress/final summary.

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

```
/domain-code-review                           # Review working tree changes
/domain-code-review abc123..def456            # Review commit range
```

Uses the same project-specific standards as Phase 5/6 review, without the full lifecycle.

### Project Layer Init

```
/plan-and-execute-init                        # Configure all project-specific files
/plan-and-execute-init --file review-standards.md  # Re-configure one file
/plan-and-execute-init --re-run               # Re-run all stages including already-filled sections
```

Guides you through filling in the project layer after install. See Step 2 above.

---

## Phase Overview

| Phase | Name | Goal | Output |
|-------|------|------|--------|
| 0 | Initialize | Conflict check, resolve config, create tracking files | `task_plan.md`, `findings.md`, `progress.md`, `review-learnings.md` |
| 1 | Concept & Design | Explore intent via brainstorming, spec, or both | Design doc and/or `spec.md` (or skip if scope is clear) |
| 2 | Research | Codebase exploration with 2-action write rule | `findings.md` populated with discoveries, blast radius, open questions |
| 3 | Plan Generation | Formal plan with 7-dimension critical analysis | Approved plan file in `docs/plans/` |
| 4 | Task Breakdown | Decompose approved plan into atomic tasks | Tasks appended to the approved plan file |
| 5 | Execution | Protocol re-read, SDD dispatch per topology, batch review gates, RALPH finalization | Implemented code, commits, `review-learnings.md` updated |
| 6 | Finalization | Security scan, config check, domain review, review-learnings consolidation, documentation gates | Final summary, branch ready for PR |

---

## Acknowledgements

- [planning-with-files](https://github.com/OthmanAdi/planning-with-files) by @OthmanAdi — persistent context management and session recovery
- [ralph-loop](https://marketplace.claudecode.dev/plugins/ralph-loop) by Anthropic — iterative convergence loop for validated execution

---

## License

[MIT](LICENSE)
