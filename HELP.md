# plan-and-execute -- Help

## What It Does

`plan-and-execute` is a unified lifecycle skill for multi-step development work. It chains
concept exploration, persistent context management, formal plan generation (with inline
quality analysis), atomic task breakdown, and RALPH-validated execution into a single
7-phase workflow. Planning files survive context compaction and session restarts. Every
phase has explicit entry/exit criteria and tracked state.

**Language focus:** Python (pytest, ruff, bandit). Adaptable to other stacks via parameter overrides.

---

## Dependencies

plan-and-execute is an **orchestrator** -- it invokes other skills/plugins at specific phases but does not reimplement their functionality. All dependencies are optional; the skill degrades gracefully.

| Dependency | Type | Where to install | Used in | Required? |
|---|---|---|---|---|
| **planning-with-files** | Plugin | Global: `~/.claude/plugins/` | Phase 0+: context file management, session hooks | Strongly recommended |
| **ralph-loop** | Plugin | Global or project: `~/.claude/plugins/` | Phase 5: RALPH convergence loop | Optional |
| **superpowers** | Plugin | Global: `~/.claude/plugins/` | Phase 1 (brainstorming), Phase 6 (branch finishing) | Optional |
| **speckit** | Commands | Global: `~/.claude/commands/speckit.*.md` | Phase 1 (specify/clarify), Phase 3-4 (tasks/analyze) | Optional |
| **claude-md-management** | Plugin | Global or project: `~/.claude/plugins/` | Phase 6: CLAUDE.md updates | Optional |
| **doc-lint / doc-sync** | Skills | Project-local: `.claude/skills/` | Phase 6: documentation audit | Optional |
| **Domain reviewer** | Agent | Project-local: `.claude/agents/` | Phase 6: domain-specific review | Optional (set via `DOMAIN_REVIEWER`) |

**If missing:** Each phase documents what happens when a dependency is unavailable -- typically a manual fallback or skip.

**Orchestration, not duplication:** plan-and-execute delegates to speckit for spec/task generation (Phase 4 "speckit path"), to ralph-loop for convergence (Phase 5), and to planning-with-files for context management (Phase 0). Its own Phase 4 "manual path" task format is a lightweight fallback for when speckit is not needed (enhancements without formal spec traceability).

---

## When to Use It

| Situation | Use plan-and-execute? |
|-----------|----------------------|
| Multi-step feature touching 3+ files | Yes |
| Work spanning multiple sessions | Yes (mandatory -- context survives compaction) |
| Refactor with significant blast radius | Yes |
| Needs formal plan before coding starts | Yes |
| Quick single-file fix (< 1 hour) | No -- use Claude directly |
| Pure research / question answering | No |
| Executing an already-written plan | Consider `speckit:implement` instead |

---

## Invocation

```
/plan-and-execute "<description>"
/plan-and-execute "<description>" MODULE_NAME=auth
/plan-and-execute "<description>" CONCEPT_MODE=skip
/plan-and-execute --help
```

The `--help` flag shows this file. The description is passed directly into the Goal field of `task_plan.md`.

### Standalone Domain Review

```
/domain-code-review                          # Review working tree changes
/domain-code-review abc123..def456           # Review commit range
/domain-code-review src/auth.py src/models.py  # Review specific files
```

Reviews code against your project's `review-standards.md`, `env-config-policy.md`, and logging policy. Does not require the full plan-and-execute lifecycle.

---

## Parameters

| Parameter | Default | Description | Example |
|-----------|---------|-------------|---------|
| `PROJECT_ROOT` | `.` | Project root directory | `my-app` |
| `MODULE_NAME` | (none) | Module being worked on | `auth`, `api`, `pipeline` |
| `PLAN_DIR` | `docs/plans` | Directory where plan.md is saved | `docs/plans` |
| `CONTEXT_DIR` | `.` | Project root -- where tracking files live | `.` |
| `SPEC_DIR` | `specs` | Agent spec files (Topology C only) | `specs` |
| `REVIEW_STANDARDS` | `docs/review-standards.md` | Review checklist path | `docs/review-standards.md` |
| `ENV_CONFIG_POLICY` | `docs/env-config-policy.md` | Environment/config policy | `docs/env-config-policy.md` |
| `DOMAIN_REVIEWER` | (none) | Domain reviewer agent name | `finanalyst-reviewer` |
| `TEST_CMD` | `python -m pytest` | Base test command | `uv run pytest` |
| `LINT_CMD` | `ruff check .` | Linter command (empty to skip) | `flake8 .` |
| `SECURITY_CMD` | `bandit -r . -ll` | Security scanner (empty to skip) | `bandit -r src/ -ll` |
| `INTEGRATION_MARKERS` | `-m integration` | Test markers for integration run | `-m integration` |
| `CONSTITUTION` | `.specify/memory/constitution.md` | Project constitution path | `.specify/memory/constitution.md` |
| `SCAN_MODE` | `docs` | Phase 2 research mode | `SCAN_MODE=full` |
| `CONCEPT_MODE` | `ask` | Phase 1 behaviour | `CONCEPT_MODE=skip` |
| `DOC_TASK_MODE` | `auto` | Phase 4 auto documentation task | `DOC_TASK_MODE=skip` |
| `logging` | (none) | Nested config block for project logging policy | See below |

Parameters not provided at invocation use their defaults. Use `project-config.yaml` to set project-wide defaults.

---

## Project Config File

Instead of passing parameters at every invocation, create `.claude/project-config.yaml`:

```yaml
plan-and-execute:
  PROJECT_ROOT: "."
  TEST_CMD: "uv run pytest"
  LINT_CMD: "uv run ruff check ."
  SECURITY_CMD: "uv run bandit -r . -ll"
  DOMAIN_REVIEWER: "my-domain-reviewer"
  REVIEW_STANDARDS: "docs/review-standards.md"
```

Invocation parameters override config file values. Config file values override skill defaults.

### Logging Configuration

The `logging:` block is an optional nested section in `project-config.yaml` that sets a project-wide logging policy. When present, the code-quality reviewer enforces compliance.

```yaml
plan-and-execute:
  logging:
    destination: "file"       # "terminal" | "file" | "both"
    file_path: "logs/app.log" # Relative to PROJECT_ROOT
    rotation: "size"          # "size" | "time" | "none"
    max_size_mb: 10           # Max file size before rotation (size only)
    backup_count: 5           # Rotated files to keep
    format: "structured"      # "structured" (JSON) | "human"
    level: "INFO"             # "DEBUG" | "INFO" | "WARNING" | "ERROR"
```

**Setup:** Run `install.sh` and answer the interactive logging questions, or add the block manually.

**What it drives:**
- `install.sh` generates a ready-to-use `logging_config.py` in your project root
- Code-quality reviewer checks: no `print()`, no `logging.basicConfig()` in modules, `getLogger(__name__)` required, format compliance
- Review standards (Section 3) enforce statement and infrastructure rules

**If omitted:** Logging compliance checks are skipped. Phase 0 will note that no logging policy is configured.

---

## Phase Overview

| Phase | Name | What happens |
|-------|------|--------------|
| 0 | Conflict Check + Initialize | Detect ralph-loop / prior sessions, resolve config, create tracking files |
| 1 | Concept & Design | Ask user: brainstorming, speckit, both, or skip -- then execute chosen path |
| 2 | Research & Discovery | Codebase exploration, findings written to disk every 2 actions |
| 3 | Plan Generation & Analysis | Inline plan + 7-dimension analysis + user approval gate |
| 4 | Task Breakdown | Atomic tasks appended to approved plan.md |
| 5 | Execution | SDD dispatch loop per topology + RALPH finalization |
| 6 | Finalization | Security check, config check, domain review, doc gates |

---

## Phase 1: Concept & Design -- Path Options

Phase 1 always asks the user which path to take (unless `CONCEPT_MODE=skip`):

| Path | Skills invoked | Output | Best for |
|------|---------------|--------|----------|
| A: Brainstorming then Spec | `superpowers:brainstorming` -> `speckit:specify` | design doc + spec.md | New/uncertain features needing both exploration and traceability |
| B: Brainstorming only | `superpowers:brainstorming` | design doc | Uncertain features without formal spec needs |
| C: Spec only | `speckit:specify` | spec.md | Well-understood features needing traceability |
| D: Skip | (none) | (none) | Clear-scope enhancements |

The agent presents a recommendation but always waits for user choice.

---

## Document Structure Created

```
<project-root>/
+-- task_plan.md          # Meta-tracker: phases, decisions, errors (created Phase 0)
+-- findings.md           # Research knowledge base (created Phase 0, updated Phase 2)
+-- progress.md           # Chronological session log (created Phase 0, updated all phases)
|
docs/
+-- plans/
    +-- YYYY-MM-DD-<feature>-design.md   # Brainstorming output (Phase 1, if Path A or B)
    +-- YYYY-MM-DD-<feature>.md          # Formal plan (Phase 3) + tasks appended (Phase 4)

specs/                    # Topology C only
+-- master-plan.md        # Orchestration flow, agent roster, contracts
+-- agent-<role>.md       # One file per agent
+-- archive/
    +-- YYYYMMDD_HHMMSS/  # Prior specs archived here before overwrite
```

---

## Bootstrap: Setting Up a New Project

If your project doesn't have review standards or config policies yet, use the included templates:

1. **Review standards:** Copy `./templates/review-standards-template.md` to `${REVIEW_STANDARDS}` and customize sections 1-5 for your domain.
2. **Config policy:** Copy `./templates/env-config-policy-template.md` to `${ENV_CONFIG_POLICY}` and adjust rules for your stack.
3. **Domain reviewer:** Copy `./templates/domain-reviewer-template.md` to `.claude/agents/${DOMAIN_REVIEWER}.md` and fill in domain-specific review criteria.
4. **Project config:** Create `.claude/project-config.yaml` with your project's parameter defaults.
5. **Logging:** Run `install.sh` with interactive logging setup, or manually add a `logging:` block to `project-config.yaml` and copy `./templates/logging_config_template.py` to your project root.

---

## Tips for Effective Use

**Start planning-with-files early.** If there's any chance this task spans sessions or
hits context limits, invoke `/planning-with-files` at the very start. plan-and-execute
Phase 0 creates these files, but if you're working interactively before invoking the
skill, start them manually to protect your research.

**Phase 1 is a user decision.** The skill always asks which concept path to take (unless
`CONCEPT_MODE=skip`). It will recommend based on task signals but will not auto-decide.
If you know your scope is clear, pass `CONCEPT_MODE=skip` to bypass the question.

**2-Action Rule is not optional.** After every 2 search/read operations in Phase 2,
write to `findings.md`. This is the mechanism that makes sessions crash-resistant.
Findings held only in context are lost to compaction.

**Topology choice matters.** The topology decision in Phase 3 determines Phase 5's
entire execution model. Default to Single Agent (A) unless the task clearly has
multiple independent workstreams. Topology C (Agent Team) is for large parallel builds
only -- the coordination overhead is significant.

**The plan file is the canonical source.** The approved plan.md drives everything in
Phases 4-6. If you need to change scope, update the plan (minor tweak) or return to
Phase 3 (significant change). Never silently absorb scope changes.

**User approval in Phase 3 is a hard gate.** The 7-dimension analyser report is
presented together with the plan. Do not move to Phase 4 without explicit approval.
This is by design -- the user needs to understand the approach before work starts.

---

## Conflict Resolution Guide

**ralph-loop is active:**
You'll see `.claude/.ralph-loop.local.md` exists. Run `/cancel-ralph` first, then
re-invoke plan-and-execute. The two skills cannot run in the same session.

**Planning files from a prior session exist:**
Read `Current Phase` in `task_plan.md`. If Phase > 0, offer to resume. Ask the user:
"Planning files found (Phase X in progress). Resume from Phase X, or start fresh?"
Do NOT auto-overwrite.

**Superpowers skills auto-trigger:**
`superpowers:brainstorming` in Phase 1 is intentional -- it is invoked by user choice.
If other superpowers skills auto-trigger during Phases 2-6 (e.g., subagent-driven-
development), follow plan-and-execute protocol instead. Do not follow both flows in
parallel -- it creates a duplicate dispatch loop and confuses tracking.

**Subagent crashes mid-task:**
1. Read `progress.md` and `task_plan.md` to identify last known state
2. Run `git log -3` to see what was committed before the crash
3. Re-dispatch a fresh subagent with the remaining work only
4. Do not retry from scratch -- partial work may already be committed

---

## Known Gaps / Manual Steps

| Gap | Manual workaround |
|-----|-------------------|
| Cross-AI validation (Claude vs GPT-4 etc.) | Run externally and paste findings into `findings.md` |
| Module-init scaffolding (INVARIANTS.md, reviewer agent) | Create manually from templates in `./templates/` |
| `doc-lint` / `doc-sync` skills may not be installed | Manually audit broken refs and stale timestamps |
| Constitution may not exist | Skip constitution check in Phase 3; note in plan |
| Security scanner may not be installed | Set `SECURITY_CMD` to empty; review CWE items manually using code-quality-reviewer |
| ralph-loop prompt assembly is manual | No skill auto-generates a per-task ralph-loop prompt from tasks.md; write it by hand using the template in Phase 5 -- paste task text + relevant review-standards items + completion promise |
| `SCAN_MODE=full` is a convention, not enforced | Nothing prevents an agent from reading docs in full mode; the discipline is in following the parameter's intent |
