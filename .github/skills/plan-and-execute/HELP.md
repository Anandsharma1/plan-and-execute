# plan-and-execute -- Help

## What It Does

`plan-and-execute` is a unified lifecycle orchestrator for multi-step development work — concept, research, plan, execute, review, finalize — with persistent context files, two-stage review, and a pluggable project layer. See `README.md` for a full overview and installation instructions.

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
| **Domain reviewer** | Agent | Project-local: `.claude/agents/` | Phase 6: domain-specific review | Default-on (`DOMAIN_REVIEWER=domain-reviewer`) |

**If missing:** Each phase documents what happens when a dependency is unavailable -- typically a manual fallback or skip.

**Missing-dependency logging policy:**
- Missing optional dependency is not an automatic failure.
- If a chosen phase path needs it, use a documented fallback and continue.
- Log only decision events:
  - Missing + fallback used -> log in `progress.md` and final summary.
  - Missing + no safe fallback -> block and escalate to user.
  - Missing + unused in this run -> do not log noise.
- Domain reviewer is default-on: if `DOMAIN_REVIEWER=domain-reviewer` is missing, flag it (do not silently skip). Disable only via `DOMAIN_REVIEWER=none`.

**Orchestration, not duplication:** plan-and-execute delegates to speckit for spec/task generation (Phase 4 "speckit path"), to ralph-loop for convergence (Phase 5), and to planning-with-files for context management (Phase 0). Its own Phase 4 "manual path" task format is a lightweight fallback for when speckit is not needed (enhancements without formal spec traceability).

---


## Invocation

```
/plan-and-execute "<description>"
/plan-and-execute "<description>" MODULE_NAME=auth
/plan-and-execute "<description>" CONCEPT_MODE=skip
/plan-and-execute --help
```

The `--help` flag shows this file. The description is passed directly into the Goal field of `task_plan.md`. On first invocation, setup runs automatically (see Setup Mode below).

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
| `DOMAIN_REVIEWER` | `domain-reviewer` | Domain reviewer agent name (set `none` to disable) | `domain-reviewer` |
| `TEST_CMD` | `uv run pytest` | Base test command | `uv run pytest app/auth/test/` |
| `LINT_CMD` | `uv run ruff check .` | Linter command (empty to skip) | `uv run ruff check src/` |
| `SECURITY_CMD` | `uv run bandit -r . -ll` | Security scanner (empty to skip) | `uv run bandit -r src/ -ll` |
| `INTEGRATION_MARKERS` | `-m integration` | Test markers for integration run | `-m integration` |
| `CONSTITUTION` | `.specify/memory/constitution.md` | Project constitution path | `.specify/memory/constitution.md` |
| `SCAN_MODE` | `docs` | Phase 2 research mode | `SCAN_MODE=full` |
| `CONCEPT_MODE` | `ask` | Phase 1 behaviour | `CONCEPT_MODE=skip` |
| `DOC_TASK_MODE` | `auto` | Phase 4 auto documentation task | `DOC_TASK_MODE=skip` |
| `logging` | (none) | Nested config block for project logging policy | See below |
| `STATE_FILE` | `.plan-and-execute.state.json` | Phase guard state file (relative to CONTEXT_DIR) | |
| `PLAN_ANALYSER` | `general-purpose` | Subagent type for Phase 3 independent plan critique; `"none"` = inline fallback | `PLAN_ANALYSER=none` |
| `REVIEW_PREAMBLE` | `.claude/shared/review-preamble.md` | Reviewer posture file injected at start of every review dispatch | |
| `PROMOTION_THRESHOLD` | `3` | Min occurrences for Phase 6 promote recommendation | `PROMOTION_THRESHOLD=2` |
| `SEVERITY_OVERRIDE_PROMOTION` | `["critical"]` | Severities that recommend promotion at 1 occurrence | |
| `DEFECTS_FILE` | `.claude/defects.jsonl` | Append-only JSONL ledger for RCA records. Committed to git — persists across feature runs. | |
| `POLICIES_FILE` | `.claude/policies.json` | Governance audit log — tracks what was promoted, when, and why. Promoted rules land in `review-standards.md`; not read by reviewer subagents. | |
| `PROMOTION_GATE_MODE` | `interactive` | Phase 6 gate mode. `interactive` = blocks until user decides each entry. `headless` = emits `promotion-bundle.json`, sets status to `needs-policy-decision`, continues without blocking. | `PROMOTION_GATE_MODE=headless` |
| `VALIDATORS` | `[]` | Validator skills to run after each task's code quality review gate. Each returns a JSON verdict. Built-ins: `wiring-auditor`, `contract-auditor`, `failure-path-auditor`, `mutation-site-auditor`, `evidence-verifier`. All off by default. Projects add custom validators at `.claude/validators/<name>/SKILL.md`. | `VALIDATORS: [wiring-auditor, evidence-verifier]` |

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
  DOMAIN_REVIEWER: "domain-reviewer"
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

**Setup:** Configured automatically during first-run setup (picks a preset), via `install.sh` (interactive shell questions), or add the block manually.

**What it drives:**
- `install.sh` generates a ready-to-use `logging_config.py` in your project root
- Code-quality reviewer checks: no `print()`, no `logging.basicConfig()` in modules, `getLogger(__name__)` required, format compliance
- Review standards (Section 3) enforce statement and infrastructure rules

**If omitted:** Logging compliance checks are skipped. Phase 0 will note that no logging policy is configured.

---

## settings.json vs settings.local.json

- `.claude/settings.json` — **committed, shared.** Quality hooks (format/lint/type-check on Edit/Write) that should apply to every developer belong here. The phase_guard.sh Stop hook is registered here by `install.sh`.
- `.claude/settings.local.json` — **per-user, uncommitted** (add to `.gitignore`). Per-user permission overrides and experimental hooks belong here.

**Common mis-placement:** If your ruff/prettier/py_compile hooks are in `settings.local.json`, they don't travel with the repo — teammates and CI won't get them. Run `install.sh` with the shared-settings option to migrate them, or move them manually.

---

## Review Artifact Contract

Four artifacts shape reviewer behavior. Each has exactly one job and one format:

| Artifact | Format | Role | Constraint |
|----------|--------|------|-----------|
| `review-standards.md` | Markdown | Durable human-facing rule library — authoritative escape-class catalog | No size limit; this is the canonical reference |
| `.claude/defects.jsonl` | JSONL | Append-only RCA ledger — one JSON record per line; last record per `id` is authoritative | Grows across runs; entries promoted via Phase 6 gate |
| `.claude/policies.json` | JSON | Governance audit log — entries promoted from defects.jsonl; promoted rules are enforced via review-standards.md; not injected into reviewer subagents | Never delete entries; only append and update |
| `.claude/shared/review-preamble.md` | Markdown | ≤80-line reviewer-action pointer — posture file injected at the start of every reviewer dispatch | Hard cap: 80 lines. Never a rules catalog. |

**Why JSON for the ledger:** `review-context-compiler` filters defects.jsonl by `applies_to` field and sorts by `severity` and `occurrences` — deterministic operations on structured data. `policy-updater` reads occurrence counts and severity to apply threshold rules. Markdown parsing for these operations is fragile; JSON is not.

**The preamble points to the standards; it does not summarize them.** If the preamble starts growing past 80 lines, content is going in the wrong place — move it to review-standards.md instead.

**defects.jsonl is institutional memory.** It accumulates across feature runs and should be committed to git. When an entry is promoted to policies.json and review-standards.md, it stays in defects.jsonl with `"status": "promoted"` — audit trail preserved. See `templates/defects-schema.md` for the full schema.

### Rule-content boundaries (non-duplication charter)

Three artifacts carry reviewer-adjacent *rules*. Each owns exactly one kind of content; content from the wrong bucket drifts and silently contradicts over time. Use this charter when deciding where a new rule belongs:

| Artifact | Owns | Must NOT own | Audience |
|----------|------|--------------|----------|
| `${REVIEW_PREAMBLE}` (default `.claude/shared/review-preamble.md`) | Loader chain (which files to read), reviewer posture (derive-status-from-code, adversarial enumeration), pointers to standards | Catalog of escape classes, severity rubric definitions, full rule text (keep pointers only) | Reviewer subagent (injected at dispatch) |
| `${REVIEW_STANDARDS}` (default `docs/review-standards.md`) | Full rule catalog: architecture/domain/clean-code/tests/invariants, severity rubric, output contract (§6) | Dispatch orchestration, prompt assembly, mirror/install mechanics | Reviewer subagent (via preamble), humans, CI |
| `CLAUDE.md § Agent Dispatch Discipline` (orchestrator-side) | Dispatch protocol (sequential write-capable agents, destructive-git prohibition, carry-open-issues-forward, sibling-pattern sweep, write-learnings-back cadence, parallel-reviewer guidance), review prompt framing | Rule text consumed inside the reviewer prompt | Orchestrator only — never injected into reviewer subagents |

**The rule:** if content fits in two buckets, the more specific (lower-in-chain) bucket wins. Preamble points to standards for rule text; standards never describe dispatch; dispatch discipline never restates review rules. A reviewer subagent should read the preamble, follow its links, and produce the §6 output — nothing the orchestrator did to dispatch it should leak into its context.

---

## Skill Decomposition Model

plan-and-execute uses a thin orchestrator + bounded specialist skills. This table is the structural rule for where new behavior belongs:

| Layer | Who | Responsibility | Must NOT do |
|-------|-----|---------------|-------------|
| **Orchestrator** | `SKILL.md` | Phase sequencing, user gates, dependency detection, fallback policy, topology choice, dispatch routing, state transitions | Implement review logic, retrospection, promotion, or validation |
| **Control skills** | `plan-analyser` | Artifact evaluation/generation with explicit input/output contracts | Read orchestrator state, write tracking files |
| **Compiler-context skills** | `review-context-compiler` | Transform `defects.jsonl` into bounded, role-filtered context packets for downstream consumers | Make policy decisions, do evaluation |
| **Validator skills** | `wiring-auditor`, `contract-auditor`, `failure-path-auditor`, `mutation-site-auditor`, `evidence-verifier` | Own exactly one risk class each; return pass/fail verdict with evidence | Know about other validators, implement multi-risk checks |
| **Learning-loop skills** | `retrospect-execution`, `policy-updater` | Capture misses and evolve policy; own the `defects.jsonl`, `policies.json`, and `review-standards.md` lifecycle | Dispatch agents, make execution decisions |

**The rule:** When adding new behavior, assign it to a layer first. If it doesn't fit cleanly, the layer boundary is wrong — fix the boundary, don't stuff the behavior into the orchestrator.

### Validator extension point

Projects plug in validators via `project-config.yaml`:

```yaml
plan-and-execute:
  VALIDATORS: [wiring-auditor, evidence-verifier, my-custom-validator]
```

Each validator is a skill at `.claude/validators/<name>/SKILL.md` with this contract:

```
Input:  TASK_ID, OWNED_FILES (list), CONTEXT (task contract text)
Output: verdict (pass|fail|skip), evidence (specific proof or "no issues found"), gaps (list, empty if pass)
```

The orchestrator discovers validators from the `VALIDATORS` list, dispatches each as a fresh subagent after the code quality review gate, and injects all verdicts into the task summary.

---

## Domain Code Review: Skill vs Agent Invocation

Two surfaces, same underlying rules:

| Surface | How it works | When to use |
|---------|-------------|-------------|
| `/domain-code-review` skill | User-invokable slash command — dispatches a fresh reviewer subagent against working tree, SHA range, or file list | Standalone review, or when you want a standards check without the full P&E lifecycle |
| `${DOMAIN_REVIEWER}` agent (default: `domain-reviewer`) | Named agent file in `.claude/agents/`; dispatched internally by plan-and-execute during Phase 5/6 | Automated review gates in the P&E execution loop |

Both read the same `review-standards.md`, `env-config-policy.md`, and `review-preamble.md`. The difference is the dispatch surface, not the rules.

---

## Known Overlapping Plugins

| Plugin / skill | Relationship | Guidance |
|---|---|---|
| `superpowers:writing-plans` + `superpowers:executing-plans` | **Do NOT combine with plan-and-execute.** P&E covers the same workflow with more phases, review gates, and state tracking. Invoking both creates two parallel planning surfaces and drifts context. | Use one or the other; default to plan-and-execute for multi-session work. |
| `superpowers:receiving-code-review` | **Complementary, not overlapping.** Targets the implementer *receiving* review (how to respond to feedback). plan-and-execute's preamble targets the reviewer *doing* review. | Use both: preamble makes reviews adversarial; receiving-code-review makes responses disciplined. |
| `superpowers:verification-before-completion` | **Complementary.** Prompt-side discipline reinforcing the FR-1 harness-side Stop hook. The hook enforces phase completion mechanically; verification-before-completion reinforces it at the agent reasoning level. | Both can be active; they address the same failure mode from different layers. |
| `claude-md-management:claude-md-improver` | **Must respect sentinel markers.** `claude-md-improver` audits and rewrites CLAUDE.md over time. It MUST NOT rewrite or delete content inside the `<!-- BEGIN plan-and-execute:agent-dispatch-discipline -->` / `<!-- END ... -->` sentinel block. Outside that block, it can audit and improve freely. | When running `claude-md-improver`, confirm it leaves the sentinel block intact. |
| `secrets-guard` (marketplace skill) | **Preferred over internal credential scanning.** P&E does not ship its own credential scanner — use `secrets-guard` + gitleaks for this. See the Non-goals section in the spec for rationale. | Install `secrets-guard` separately if credential scanning is needed. |

---

## Phase Overview

| Phase | Name | What happens |
|-------|------|--------------|
| 0 | Conflict Check + Initialize | Detect ralph-loop / prior sessions, resolve config, create tracking files, write initial state file |
| 1 | Concept & Design | Ask user: brainstorming, speckit, both, or skip -- then execute chosen path |
| 2 | Research & Discovery | Codebase exploration, findings written to disk every 2 actions |
| 3 | Plan Generation & Analysis | Plan + fresh-subagent critic dispatch (PLAN_ANALYSER) + user approval gate |
| 4 | Task Breakdown | Atomic tasks appended to approved plan.md |
| 5 | Execution | Protocol re-read, SDD dispatch per topology, batch review gates, RALPH finalization, Phase 5->6 hard gate |
| 6 | Finalization | Security check, config check, domain review, promotion gate, doc gates, state file set to complete |

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

## Setup Mode

On first invocation, plan-and-execute checks for `.claude/.plan-and-execute-setup.done`. If absent, it offers to run guided setup before proceeding. Setup instructions live in `setup-prompt.md` and are only loaded during this one-time flow.

### What it does

1. **Auto-detects** your test runner, linter, security scanner, project structure, config framework, and .env patterns from the codebase (assumes `uv` as package manager)
2. **Asks 2 questions**: domain name and logging preset (backend/cli-tool/skip)
3. **Generates files**: `project-config.yaml` (with `DOMAIN_REVIEWER: "domain-reviewer"` by default), `review-standards.md`, `env-config-policy.md`, domain reviewer agent, `logging_config.py` (optional)
4. **Creates marker** `.claude/.plan-and-execute-setup.done` so setup doesn't trigger again
5. **Prints a summary** showing what was generated and what still needs manual customization

Never overwrites existing files. To re-run setup, delete `.claude/.plan-and-execute-setup.done`.

### What still needs manual attention after setup

- `docs/review-standards.md` sections 2 (domain-specific rules) and 5 (invariants)
- `.claude/agents/domain-reviewer.md` domain-specific review criteria
- Any auto-detected values that don't match your actual setup
- If you want to disable domain reviewer, set `DOMAIN_REVIEWER: "none"` manually in `project-config.yaml`

### Alternative: Shell installer

For non-interactive environments, use the shell-based installer:

```bash
./install.sh /path/to/project
```

This copies templates and offers interactive logging configuration via shell prompts.

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

**Subagents don't inherit your context.** Agents dispatched via the Task tool do NOT
get CLAUDE.md, session hooks, or loaded skills. The orchestrator must paste relevant
project standards (logging format, exception handling, import order, type hints) into
every implementer prompt. The implementer-prompt.md template has a Project Standards
section for this purpose.

**Review preamble is the injection mechanism.** The `review-preamble.md` file (≤80 lines) is injected at the top of every reviewer dispatch. It establishes adversarial posture and points reviewers to `review-standards.md`. Creating the file without updating reviewer prompts is a no-op — the prompts already include the injection instruction, but `install.sh` must scaffold the file first.

**Phase 5 has mandatory gates.** Three enforcement points prevent skipping process:
1. **Protocol re-read (step 2)**: Before any dispatch, re-read the prompt templates and review standards. This prevents context compaction from dropping process requirements.
2. **Batch review gate (step 5a)**: After each parallel batch, run lint + `/domain-code-review` on the cumulative diff. This catches cross-task issues that individual self-reviews miss.
3. **Hard gate (step 13)**: Phase 5 cannot be declared complete until all tasks are done, batch review has run, and RALPH finalization has passed. "All tasks implemented" != "Phase 5 complete".

**Phase 6 is mandatory, not optional.** Phase 6 runs domain-code-review, security
check, defect retrospection (`retrospect-execution`), policy promotion gate
(`policy-updater`), and documentation gates. Completing all tasks in Phase 5 does NOT
mean the feature is done -- Phase 6 is where project standards compliance is verified.

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
| Phase guard Stop hook requires `install.sh` to register | If not registered, manually add `hooks/phase_guard.sh` to `.claude/settings.json` `hooks.Stop` array |
| MediMigration users: FR-1 state file may conflict with `.harness/runs/<id>/run.json` | Do NOT adopt FR-1 on MediMigration — its `harness_phase_guard.sh` covers the same enforcement against its own state. Keep the P&E state file only on projects without a pre-existing harness layer. |
| Worktree users: state file is per-worktree | This is correct behavior — each worktree is an independent feature run. The hook reads the state file in `CLAUDE_PROJECT_DIR`, which is the worktree root. |
| Cross-AI validation (Claude vs GPT-4 etc.) | Run externally and paste findings into `findings.md` |
| Module-init scaffolding (INVARIANTS.md, reviewer agent) | Create manually from templates in `./templates/` |
| `doc-lint` / `doc-sync` skills may not be installed | Manually audit broken refs and stale timestamps |
| Constitution may not exist | Skip constitution check in Phase 3; note in plan |
| Security scanner may not be installed | Set `SECURITY_CMD` to empty; review CWE items manually using code-quality-reviewer |
| ralph-loop prompt assembly is manual | No skill auto-generates a per-task ralph-loop prompt from tasks.md; write it by hand using the template in Phase 5 -- paste task text + relevant review-standards items + completion promise |
| `SCAN_MODE=full` is a convention, not enforced | Nothing prevents an agent from reading docs in full mode; the discipline is in following the parameter's intent |
| Subagents don't inherit CLAUDE.md or skills | Orchestrator must paste project standards into every implementer prompt (use the Project Standards section in implementer-prompt.md) |
| Context compaction drops process steps | The protocol re-read (Phase 5 step 2) and session-resume reminders (if configured) mitigate this but cannot fully prevent it |
