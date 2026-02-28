---
name: plan-and-execute
description: Use when starting a multi-step feature, bugfix, or refactor that needs research, formal planning, and validated execution with persistent context across phases
user-invokable: true
argument-hint: "<feature request, bug description, or task description>"
---

# Plan and Execute

Unified lifecycle skill: persistent context management + concept exploration + formal plan generation + task breakdown + validated execution. Seven phases with clear handoffs, conflict detection, and no duplicate tracking.

**Language focus:** Python (pytest, ruff, bandit). Adaptable to other stacks via parameter overrides.

## Dependencies

This skill is an **orchestrator** -- it invokes other skills at specific phases but does not reimplement their functionality. All dependencies are optional; the skill degrades gracefully when a dependency is unavailable.

| Dependency | Type | Install scope | Used in | Required? | What happens if missing |
|---|---|---|---|---|---|
| **planning-with-files** | Plugin | Global (`~/.claude/plugins/`) | Phase 0 (init), all phases (context injection) | **Strongly recommended** | Lose automatic `task_plan.md` context injection and session-catchup. Manual recovery still works via git + file reads. |
| **ralph-loop** | Plugin | Global or project (`~/.claude/plugins/`) | Phase 5 (RALPH finalization) | Optional | Run the validation suite manually (tests, lint, quality review) without the convergence loop. |
| **superpowers** | Plugin | Global (`~/.claude/plugins/`) | Phase 1 (brainstorming), Phase 5 (SDD model), Phase 6 (branch finishing) | Optional | Phase 1: skip brainstorming path or do it manually. Phase 5: dispatch subagents directly. Phase 6: create PR manually. |
| **speckit** | Commands | Global (`~/.claude/commands/speckit.*.md`) | Phase 1 (specify, clarify), Phase 3 (specify gate), Phase 4 (tasks, analyze) | Optional | Use the manual paths instead -- plan-and-execute provides its own task breakdown format for when speckit is unavailable. |
| **claude-md-management** | Plugin | Global or project (`~/.claude/plugins/`) | Phase 6 (CLAUDE.md update) | Optional | Skip CLAUDE.md revision; update manually if needed. |
| **doc-lint / doc-sync** | Skills | Project-local (`.claude/skills/`) | Phase 6 (documentation gates) | Optional | Manually audit documentation for broken refs and staleness. |
| **Domain reviewer** | Agent | Project-local (`.claude/agents/`) | Phase 6 (domain review) | Optional | Set `DOMAIN_REVIEWER` param. If unset, domain review is skipped entirely. |

### Orchestration vs. Duplication Boundaries

plan-and-execute does NOT reimplement these skills. It **delegates** to them:

| Concern | Who owns it | plan-and-execute's role |
|---|---|---|
| **Spec creation** (requirements, acceptance criteria) | `speckit:specify` / `speckit:clarify` | Invokes speckit in Phase 1 or Phase 3 when user chooses the speckit path. Does not generate specs itself. |
| **Task generation from spec** | `speckit:tasks` | Invokes `speckit:tasks` in Phase 4 when a spec.md exists. speckit produces tasks in its own format (checkbox + TaskID + [P] + [Story]). |
| **Task generation without spec** | plan-and-execute (Phase 4 manual path) | When speckit is not used (no spec.md), plan-and-execute has its own lightweight task format (`T-<N>` with Goal/Files/Acceptance/Dependencies). This is NOT a duplicate of speckit -- it's the fallback for enhancement work that doesn't need formal spec traceability. |
| **Context file management** | planning-with-files plugin | plan-and-execute invokes `/planning-with-files` in Phase 0. It writes to `task_plan.md`, `findings.md`, `progress.md` using the files the plugin created. It does not reimplement the plugin's hooks or session-catchup. |
| **Iterative convergence** | ralph-loop plugin | plan-and-execute invokes `/ralph-loop` in Phase 5 for the RALPH finalization loop. It does not reimplement the convergence mechanism. |
| **Brainstorming / design exploration** | `superpowers:brainstorming` | plan-and-execute invokes it in Phase 1 when user selects Path A or B. Does not reimplement structured dialogue. |
| **Subagent dispatch model** | `superpowers:subagent-driven-development` | plan-and-execute uses the SDD *pattern* (fresh subagent per task) but dispatches with its own prompt templates. It does not invoke the SDD skill directly -- it implements the dispatch loop with two-stage review on top. |
| **Branch completion** | `superpowers:finishing-a-development-branch` | Invoked in Phase 6. Not reimplemented. |

### Installation Check

At Phase 0, plan-and-execute should check which dependencies are available and log them in `task_plan.md`. This informs which paths are available in later phases:

```
## Available Dependencies
| Dependency | Available? | Notes |
|---|---|---|
| planning-with-files | yes/no | |
| ralph-loop | yes/no | |
| superpowers | yes/no | |
| speckit | yes/no | |
| ${DOMAIN_REVIEWER} | yes/no/not configured | |
```

## Parameters

Provide at invocation, or accept defaults. Override per-project via `project-config.yaml` (see below).

| Parameter | Default | Description |
|-----------|---------|-------------|
| PROJECT_ROOT | `.` | Root directory of the target project, relative to the git repo root. All other relative paths resolve under this. |
| MODULE_NAME | (none — optional) | e.g. `auth`, `api`, `pipeline`. Scopes linting, security checks, and domain review. |
| PLAN_DIR | `${PROJECT_ROOT}/docs/plans` | Where plan.md is saved |
| CONTEXT_DIR | `${PROJECT_ROOT}` | Where task_plan.md / findings.md / progress.md live |
| SPEC_DIR | `${PROJECT_ROOT}/specs` | Agent spec files (Topology C only) |
| REVIEW_STANDARDS | `${PROJECT_ROOT}/docs/review-standards.md` | Module review checklist. Create from `./templates/review-standards-template.md` if missing. |
| ENV_CONFIG_POLICY | `${PROJECT_ROOT}/docs/env-config-policy.md` | Environment/config policy. Create from `./templates/env-config-policy-template.md` if missing. |
| DOMAIN_REVIEWER | (none — optional) | Agent name for domain-specific review in Phase 6 (e.g. `finanalyst-reviewer`, `schemabridge-reviewer`). If unset, domain review is skipped. |
| TEST_CMD | `python -m pytest` | Base test command (run from `${PROJECT_ROOT}`). Override for your runner: `uv run pytest`, `poetry run pytest`, etc. |
| LINT_CMD | `ruff check ${PROJECT_ROOT}/` | Linter command. Set to empty string to skip. Override for your linter: `flake8`, `pylint`, etc. |
| SECURITY_CMD | `bandit -r ${PROJECT_ROOT}/ -ll` | Security scanner command. Set to empty string to skip. |
| INTEGRATION_MARKERS | `-m integration` | Markers for integration test run |
| CONSTITUTION | `${PROJECT_ROOT}/.specify/memory/constitution.md` | Project constitution path (if exists) |
| SCAN_MODE | `docs` | Phase 2 research mode: `docs` = use existing documentation as navigation guide; `full` = scan codebase directly, treat docs as untrustworthy or absent |
| CONCEPT_MODE | `ask` | Phase 1 behaviour: `ask` = present concept/design options to user; `skip` = jump straight to Phase 2 research (for enhancements with clear scope) |
| DOC_TASK_MODE | `auto` | Phase 4 documentation task: `auto` = always append a mandatory documentation task as the last task; `skip` = no auto-generated doc task |
| logging | (none — optional) | Nested config block (`destination`, `file_path`, `rotation`, `max_size_mb`, `backup_count`, `format`, `level`). Set once via `install.sh` or manually in `project-config.yaml`. When present, code-quality reviewer enforces logging compliance. |

### Project Config File (Optional)

Instead of passing parameters at every invocation, create a `project-config.yaml` in `${PROJECT_ROOT}/.claude/` or `${PROJECT_ROOT}/`:

```yaml
# .claude/project-config.yaml
plan-and-execute:
  PROJECT_ROOT: "."
  TEST_CMD: "uv run pytest"
  LINT_CMD: "uv run ruff check ."
  SECURITY_CMD: "uv run bandit -r . -ll"
  INTEGRATION_MARKERS: "-m integration"
  DOMAIN_REVIEWER: "my-domain-reviewer"
  REVIEW_STANDARDS: "docs/review-standards.md"
  ENV_CONFIG_POLICY: "docs/env-config-policy.md"
  DOC_TASK_MODE: "auto"
  # logging:                    # Optional — set via install.sh or manually
  #   destination: "file"       # "terminal" | "file" | "both"
  #   file_path: "logs/app.log"
  #   rotation: "size"          # "size" | "time" | "none"
  #   max_size_mb: 10
  #   backup_count: 5
  #   format: "structured"      # "structured" (JSON) | "human"
  #   level: "INFO"
```

Parameters at invocation override config file values. Config file values override skill defaults.

## Architecture

```
concept & design         planning-with-files          plan generation         task breakdown + execution
(brainstorming/spec)     (persistent context)         (formal plan)           (RALPH-validated)
       |                        |                          |                        |
       v                        v                          v                        v
  design doc / spec.md     task_plan.md <-- meta       docs/plans/*.md <-- plan   TaskUpdate <-- steps
  (optional upstream)      findings.md  <-- research   (RALPH criteria,           progress.md <-- log
                           progress.md  <-- session     topology, steps)
                                                              |
                                                       tasks section <-- Phase 4 breakdown
```

**Each file has ONE job:**

| File | Role | Updated by |
|------|------|------------|
| `task_plan.md` | Meta-workflow tracker (which phase am I in?) | All phases |
| `findings.md` | Research knowledge base | Phase 2 (Research) |
| `progress.md` | Chronological session log | All phases |
| `review-learnings.md` | Accumulated review patterns (user-reported gaps + auto-detected) | Phase 5 (execution), Phase 6 (promotion) |
| `docs/plans/*.md` | Formal RALPH implementation plan + tasks | Phase 3 (Plan) + Phase 4 (Tasks) |

**Conflict rules:**
- `task_plan.md` is NOT the implementation plan -- that lives in `docs/plans/`
- `findings.md` feeds into Phase 3 plan generation -- no duplicate codebase exploration

**TaskUpdate vs planning-with-files (progress.md):**
- `TaskUpdate` is an in-session tool (in-memory, lost on session end) the orchestrator uses to track step status within the current session.
- planning-with-files provides the durable cross-session record via `progress.md`.
- The two are complementary: `TaskUpdate` gives a live in-session step view; planning-with-files gives crash-resistant state that survives compaction and restart.
- **Subagents must not invoke planning-with-files directly**, even though they technically have access to it. A subagent lacks the full orchestrator context (active phase, other in-flight subagents) and a concurrent write from a subagent would produce conflicting, inconsistent state. Subagents return results as output text; the orchestrator consolidates and surfaces them to planning-with-files.

## Prompt Templates & Supporting Files

| File | Used in | Purpose |
|------|---------|---------|
| `./implementer-prompt.md` | Phase 5 (Topology A/B) | Fresh subagent implementation -- TDD, self-review, structured report |
| `./spec-reviewer-prompt.md` | Phase 5 (Topology A/B) | Adversarial task-level spec compliance verification |
| `./agent-spec-reviewer-prompt.md` | Phase 5 (Topology C) | Agent-level spec verification -- outputs, file ownership, RALPH criteria |
| `./code-quality-reviewer-prompt.md` | Phase 5 (all topologies) | Git SHA-scoped code quality review (SOLID, DRY, YAGNI, CWE security, config sprawl) |
| `./skills/domain-code-review/SKILL.md` | Phase 5 + 6, standalone | Project-specific review: review-standards.md, env-config-policy, logging compliance. Also invocable as `/domain-code-review`. |
| `./task-plan-template.md` | Phase 0 | 7-phase task_plan.md template with Plan Details tracking table |
| `./review-learnings-template.md` | Phase 0 | Starter review-learnings.md — accumulated review patterns during execution |
| `./setup-prompt.md` | Phase 0 (first run only) | Auto-detection + guided setup flow — loaded when `.claude/.plan-and-execute-setup.done` is absent |

### Bootstrap Templates (for new projects)

| File | Purpose |
|------|---------|
| `./templates/review-standards-template.md` | Starter review-standards.md -- customize per project |
| `./templates/env-config-policy-template.md` | Starter env-config-policy.md -- customize per project |
| `./templates/domain-reviewer-template.md` | Starter domain reviewer agent -- customize per domain |

## Session Recovery

Before starting, check for unsynced context from a previous session. Try the planning-with-files catchup script if available, otherwise fall back to manual recovery:

```bash
# Try automated catchup (may not be available in all environments)
CATCHUP_SCRIPT="$(find ~/.claude/plugins/cache/planning-with-files -name session-catchup.py 2>/dev/null | head -1)"
if [ -n "$CATCHUP_SCRIPT" ]; then
  $(command -v python3 || command -v python) "$CATCHUP_SCRIPT" "$(pwd)"
fi
```

If the script is unavailable or if catchup report shows unsynced context, do manual recovery:
1. Run `git diff --stat` and `git log --oneline -10` to see recent changes
2. Read existing planning files in order: `task_plan.md` -> `findings.md` -> `progress.md`
3. Update planning files based on what git shows vs. what's logged
4. Resume from the last incomplete phase

## Phase 0: Conflict Check + Initialize Context Files

**Setup check:** Before parameter resolution, check if setup has been completed:
- Check: `.claude/.plan-and-execute-setup.done` exists?
  → If YES: skip setup, proceed to parameter resolution.
  → If NO: Ask "No project setup found. Run setup to auto-detect your project? [Y/n]"
    - If Y: Read `./setup-prompt.md` and execute the setup flow. After setup completes, continue with parameter resolution below.
    - If N: use skill defaults, proceed normally.
- To re-run setup later, delete `.claude/.plan-and-execute-setup.done`.

**Parameter resolution:** Resolve parameters:
1. Check for `project-config.yaml` in `${PROJECT_ROOT}/.claude/` or `${PROJECT_ROOT}/`
2. If found, load `plan-and-execute` section as base values (including `logging:` block if present)
3. Apply any invocation-time overrides on top
4. Apply skill defaults for anything still unset
5. Log resolved parameters in `task_plan.md` Parameters table
6. If `logging:` block exists in config, note it in Parameters table — this drives code-quality review enforcement. If absent and this is the first run, inform user: "No logging policy configured. Delete `.claude/.plan-and-execute-setup.done` and re-run to trigger setup, or add a `logging:` section to `project-config.yaml` manually."

**Dependency check:** Detect which optional dependencies are available and log in `task_plan.md`:
- `planning-with-files`: Check if `/planning-with-files` skill is available
- `ralph-loop`: Check if `/ralph-loop` skill is available
- `superpowers`: Check if `superpowers:brainstorming` skill is available
- `speckit`: Check if `speckit:specify` skill/command is available
- `${DOMAIN_REVIEWER}`: Check if the agent file exists at `.claude/agents/${DOMAIN_REVIEWER}.md`

This determines which paths are available in later phases. If a dependency is missing, the skill falls back to manual alternatives (documented in each phase).

**Conflict checks BEFORE touching any files:**

1. **ralph-loop active?**
   Check: `.claude/.ralph-loop.local.md` exists
   -> STOP. Output: "ralph-loop is currently active. plan-and-execute cannot run
   alongside it. Cancel with `/cancel-ralph` first, then re-invoke."
   -> Do NOT proceed without user resolution.

2. **Planning files from a prior session?**
   Check: `${CONTEXT_DIR}/task_plan.md` exists
   -> Read Current Phase field
   -> If Phase > 0: "Planning files found (Phase X in progress). Resume from Phase X,
   or confirm 'start fresh' to overwrite."
   -> Do NOT auto-overwrite. Wait for user decision.

3. **Superpowers auto-trigger note** (cannot detect programmatically):
   If superpowers skills auto-trigger during execution (Phases 2-6), follow plan-and-execute
   protocol instead. Do not follow the superpowers flow in parallel.
   **Exception:** `superpowers:brainstorming` is explicitly invoked in Phase 1 when the user
   selects it -- this is intentional, not an auto-trigger conflict.

**Initialize files** (after conflict checks pass):

1. Invoke `/planning-with-files` with the feature description. This activates the plugin's session hooks -- before every tool call, the hook automatically injects the top 30 lines of `task_plan.md` into context.

2. Immediately overwrite `task_plan.md` with the plan-and-execute structure from `./task-plan-template.md`, filling in Goal, MODULE_NAME, and resolved parameters from the user's request. The plugin reads `task_plan.md` as LLM context (not a parsed schema), so it works correctly with the 7-phase checklist and Plan Details table.

`findings.md` and `progress.md` as created by the plugin are used as-is.

3. Create `${CONTEXT_DIR}/review-learnings.md` from `./review-learnings-template.md`. This file accumulates review patterns during Phase 5 execution (user-reported gaps + auto-detected patterns). Reviewers load it before each dispatch.

## Phase 1: Concept & Design

**Goal:** Establish the conceptual foundation before research begins. Explore intent, requirements, and approach at the right level of formality for this task.

**If `CONCEPT_MODE=skip`:** Mark Phase 1 complete in `task_plan.md` and proceed directly to Phase 2. Use this for well-understood enhancements where scope is already clear.

**If `CONCEPT_MODE=ask` (default):** Present the following options to the user and wait for their choice. Do NOT auto-decide.

| Path | When to use | What happens | Output |
|------|-------------|--------------|--------|
| **A: Brainstorming then Spec** | New/uncertain feature where requirements need structured exploration AND formal traceability | 1. Invoke `superpowers:brainstorming` -- asks questions one at a time, proposes 2-3 approaches with trade-offs, gets approval section by section. 2. After brainstorming completes, invoke `speckit:specify` using the design doc as input -- formalizes requirements into a spec with acceptance criteria. Optionally run `speckit:clarify` if gaps remain. | design doc + `spec.md` |
| **B: Brainstorming only** | Uncertain feature, but no formal spec traceability needed | Invoke `superpowers:brainstorming` -- structured dialogue, design doc output. Proceed to Phase 2 with design doc as context. | design doc (`${PLAN_DIR}/YYYY-MM-DD-<feature>-design.md`) |
| **C: Spec only** | Well-understood feature that needs formal traceability but not design exploration | Invoke `speckit:specify` directly from user's description. Optionally run `speckit:clarify` if gaps exist. | `spec.md` |
| **D: Skip** | Enhancement with clear, bounded scope -- no concept work needed | Proceed directly to Phase 2 research. | (none) |

**Execution rules:**
- **Always ask the user which path.** The decision table above is guidance, not an auto-decision matrix. Present the options with a brief recommendation based on the task signals, but the user chooses.
- For Path A, brainstorming must complete and produce a design doc BEFORE speckit is invoked. The design doc is the input to `speckit:specify`.
- For Path A and C, the `spec.md` produced here replaces `findings.md` as the primary requirements source in Phase 3 (Plan Generation). `findings.md` still supplies codebase research from Phase 2.
- For Path B, the design doc feeds into Phase 3 as supplementary context alongside `findings.md`.
- Log the chosen path and any outputs in `progress.md` and `task_plan.md` Decisions Made table.

**Update `task_plan.md`:** Set Current Phase to Phase 1, record the chosen path. After completion, update Phase 1 status to complete.

## Phase 2: Research & Discovery

**Goal:** Understand the codebase and problem space. All discoveries go to `findings.md`.

1. **Parse the user's request** -- extract What, Why, and Constraints. Write them into `findings.md` Requirements section. If Phase 1 produced a design doc or spec.md, reference its key decisions here -- do not repeat them.

2. **Explore the codebase** -- mode depends on `SCAN_MODE`:

   **`SCAN_MODE=docs` (default):** Start from documentation, then dive into code.
   - Read `${PROJECT_ROOT}/docs/README.md` and `${PROJECT_ROOT}/CLAUDE.md` for navigation
   - Use Grep/Glob to locate relevant files and functions under `${PROJECT_ROOT}/`
   - Read existing implementation, data models, control flow
   - Check for existing solutions or extensible abstractions
   - Check `${PROJECT_ROOT}/tests/` for existing test patterns

   **`SCAN_MODE=full`:** Skip documentation -- scan the codebase directly. Use when docs are stale, absent, or you want an unbiased read of actual code behaviour.
   - Use Grep/Glob broadly across `${PROJECT_ROOT}/`, config files
   - Read actual source files, data models, and test files directly -- do not rely on README or ARCHITECTURE.md to interpret what you find
   - Treat any documentation you encounter as potentially stale; verify claims against the code
   - This mode is slower but produces findings that reflect the real codebase state, not the documented intent

3. **Apply the 2-Action Rule:** After every 2 search/read operations, update `findings.md` with discoveries. Do not accumulate findings in context only.

4. **Identify:**
   - Blast radius (which files/modules are affected)
   - Dependencies and constraints
   - Open questions and assumptions

5. **Update `progress.md`:** Log actions taken, files examined, key discoveries, and open questions.

## Phase 3: Plan Generation & Analysis

**Goal:** Produce a formal RALPH implementation plan and critically evaluate it before execution. This phase is self-contained -- no external skills are called.

**Decision: speckit upstream gate or direct plan generation?**

If Phase 1 already produced a `spec.md` (Path A or C), skip the speckit decision below -- the spec is already available. Use `spec.md` as the primary requirements source and `findings.md` as the codebase research source.

If Phase 1 did NOT produce a `spec.md`, use this table to decide:

| Signal | Path |
|--------|------|
| New module or greenfield feature -- requirements are not yet fully clear | **speckit first**: `speckit:specify` -> `speckit:clarify` -> generate plan consuming `spec.md` + `findings.md` |
| Feature where acceptance criteria need explicit traceability to spec | **speckit first** (same as above) |
| Enhancement to an established module with clear, bounded requirements | **Direct**: generate plan from `findings.md` only |
| Exploratory or time-pressured -- scope likely to shift | **Direct**: plan is easier to revise without a formal spec artifact |

For the speckit path (when spec.md doesn't yet exist), run `speckit:specify` (and `speckit:clarify` if gaps exist) before step 1 below. The generated `spec.md` replaces `findings.md` as the primary requirements source for plan generation; `findings.md` still supplies the codebase research.

1. **Re-read `task_plan.md` and `findings.md`** -- refresh goals and discoveries in the attention window. If Phase 1 produced a design doc or spec.md, re-read those too.

2. **Check constitution** (if `${CONSTITUTION}` exists):
   Read the constitution file and verify the planned approach aligns with its principles.
   Record the verdict in the plan under a "Constitution Check" section:

   | Verdict | Meaning | Action |
   |---------|---------|--------|
   | **ALIGNED** | Approach conforms to all constitution principles | Proceed |
   | **TENSION** | Approach diverges but has valid justification | Document the justification explicitly in the plan; flag for user awareness at approval |
   | **VIOLATION** | Approach directly contradicts a constitution principle | Revise the approach; if the violation is unavoidable (e.g. third-party constraint), escalate to user with a specific constitutional exception request before proceeding |

   Do not proceed to step 3 with an unresolved VIOLATION.

3. **Design the plan** (consuming `findings.md` and any Phase 1 artifacts as primary sources):
   - Skip redundant codebase exploration -- use findings.md
   - Only do targeted follow-up reads for specific details not yet captured
   - Design the approach with generic-over-specific constraints
   - Define RALPH validation criteria (per-phase and plan-level)

   **Plan format** -- save to `${PLAN_DIR}/YYYY-MM-DD-<feature-name>.md` containing:
   - Goal (one sentence)
   - Constitution Check (result of step 2)
   - Approach (phased, architecture decisions)
   - Execution Topology (with justification from decision table below)
   - Phases with high-level outcomes
   - RALPH Criteria (per-phase and plan-level success criteria)
   - Out of scope

4. **Determine Execution Topology** -- this is an explicit architectural decision:

   | Factor | Single Agent (A) | Coordinated Sub-Agents (B) | Agent Team (C) |
   |--------|-----------------|--------------------------|----------------|
   | Files touched | <=3 | 4-10 | 10+ |
   | Independent workstreams | 1 | 2-4 | 3+ with interfaces |
   | Inter-component contracts | None | Minimal | Defined I/O per agent |
   | Context window pressure | Low | Medium | High (needs splitting) |
   | Role specialization needed | No | No | Yes |

   **Default to the simplest topology that fits.** Over-engineering topology is as bad as under-engineering code.

   **What each topology requires in the plan:**
   - **Single Agent**: Steps section with linear ordering + parallelization markers
   - **Coordinated Sub-Agents**: Steps grouped by workstream, parallelized where safe. No shared mutable state between sub-agents.
   - **Agent Team**: Full spec file protocol -- create `specs/master-plan.md` (orchestration flow, agent roster, contracts) + one `specs/agent-<role>.md` per agent. Archive pre-existing specs to `specs/archive/YYYYMMDD_HHMMSS/`. No file ownership overlap between agents.

   Record the chosen topology and justification in the plan's "Execution Topology" section.

5. **Analyse the plan** -- 7-dimension critical evaluation (inline, no external skill needed):

   | # | Dimension | What it checks |
   |---|-----------|----------------|
   | 1 | Architectural Soundness | Aligns with existing patterns; constitution check present |
   | 2 | Generic & Scalable Design | No regex shortcuts, no hardcoded domain knowledge |
   | 3 | Edge Cases & Failures | Empty inputs, data gaps, external service failures, domain-specific edge cases |
   | 4 | Scope & Boundaries | Explicit file lists, no unbounded scope |
   | 5 | Success Criteria & RALPH | Measurable, verifiable, per-phase + plan-level criteria |
   | 6 | Sequence & Dependencies | Correct ordering, parallelization, no broken intermediate states |
   | 7 | Topology Justification | Topology choice justified against the decision table |

   **Handle the verdict:**

   ```
   +------------------+
   |  Plan Analysis   |
   +--------+---------+
            v
   +------------------+
   |    Verdict?      |
   +--+-------+---+---+
      |       |   |
   PROCEED  PROCEED  BLOCK
      |    WITH CHANGES |
      |       |         |
      |  Apply amendments    Fix BLOCKERs
      |  to the plan.        (re-read findings.md,
      |  Log changes in      targeted codebase reads),
      |  findings.md         then re-analyse
      |  (Technical          (max 2 revision cycles)
      |   Decisions)         |
      |       |              |
      v       v              v
   +---------------------------------+
   | Present plan + analyser report  |
   | to user for approval            |
   +---------------------------------+
   ```

   - **PROCEED** -> move to user approval
   - **PROCEED WITH CHANGES** -> apply amendments, log in `findings.md` Technical Decisions, then present for approval
   - **BLOCK** -> fix issues, save revised plan, re-analyse. Max 2 re-analysis cycles -- if still BLOCK, escalate to user with: which dimensions are blocking, what was tried, specific decision needed to unblock

6. **Present the plan AND the analyser report to the user for approval.** Show the dimension verdicts table. Do not proceed to Phase 4 without explicit user approval.

7. **Update `progress.md`:** Log plan generation, topology decision, analyser verdict (with dimension breakdown), re-analysis cycles (if any), user approval status. Log any amendments and their rationale in `findings.md` Technical Decisions section.

## Phase 4: Task Breakdown

**Goal:** Break the approved plan's phases into atomic tasks. This phase produces the work queue for Phase 5 execution.

**Two paths -- choose based on whether speckit is available AND a spec.md exists:**

### Path A: Delegate to speckit (when spec.md exists AND speckit is available)

speckit owns task generation. plan-and-execute invokes it, does not reimplement it:

```
speckit:tasks (consuming approved plan.md + spec.md)
  -> tasks.md with dependency-ordered atomic tasks
  -> speckit's own format: checkbox + TaskID + [P] marker + [Story] label + file path
speckit:analyze
  -> validates spec + plan + tasks consistency
```

plan-and-execute consumes speckit's output as-is for Phase 5 execution.

### Path B: Manual task breakdown (when speckit is unavailable OR no formal spec)

This is NOT a reimplementation of speckit -- it's a lightweight fallback for enhancement work that doesn't need formal spec traceability. The format is intentionally simpler:

For each phase in the approved plan, decompose into atomic tasks:
- Each task: one agent session can complete it end-to-end
- Each task must have: goal, files to touch, acceptance criteria, dependencies (task IDs)
- For Topology B/C: group tasks by workstream and mark parallelization opportunities

**Output:** Append a **Tasks** section to the bottom of the already-approved plan file (`${PLAN_DIR}/YYYY-MM-DD-<feature>.md`). Same file the user approved -- tasks are an addendum, not a separate artifact. Each task entry:

```
### Task T-<N>: <short title>
- **Goal:** one sentence
- **Files to touch:** explicit list
- **Acceptance criteria:** measurable and verifiable
- **Dependencies:** [T-1, T-2] or "none"
```

**Mandatory documentation task** (when `DOC_TASK_MODE=auto`):

The **last task** in every plan must be a documentation task. This task:

- Identifies all modules and sub-modules touched by the plan
- For each touched module/sub-module, checks whether `README.md` and `ARCHITECTURE.md` exist in that directory
- **Creates** them if missing -- derive content from the actual code, not from assumptions:
  - `README.md`: purpose, usage, key files/classes, dependencies on other modules
  - `ARCHITECTURE.md`: design decisions, data flow, component interactions, key abstractions
- **Updates** them if they exist but are stale relative to the changes made in this plan
- For **parent directories** that aggregate multiple touched sub-modules, creates or updates integration-level documentation explaining how the sub-modules work together
- Documentation is **hierarchical**: sub-module -> module -> parent (only where relevant -- don't create docs at levels that add no value)

This task goes through the same two-stage review (spec compliance + code quality) as implementation tasks.

Example:
```
### Task T-<last>: Update module documentation
- **Goal:** Create or update README.md and ARCHITECTURE.md for all modules touched by this plan
- **Files to touch:** <module>/README.md, <module>/ARCHITECTURE.md (for each touched module/sub-module)
- **Acceptance criteria:**
  - Every module/sub-module touched by prior tasks has a README.md (purpose, usage, key files)
  - Every module/sub-module with non-trivial design has an ARCHITECTURE.md (design, data flow, interactions)
  - Parent modules have integration-level docs if 2+ sub-modules were touched
  - All docs reflect the actual code state, not stale or aspirational content
- **Dependencies:** [all prior tasks]
```

Log the number of tasks and workstream groupings (if Topology B/C) in `progress.md`.

## Phase 5: Execution

**Goal:** Execute the approved plan with RALPH validation. Dispatch according to the topology chosen in Phase 3.

1. **Re-read `task_plan.md`** -- confirm you're in Phase 5, the plan is approved, and note the chosen topology.

2. **Pre-execution gate:** Verify NOT on main/master branch. If on main -> stop and ask user to create a feature branch or use a git worktree.

3. **Read the plan** from `docs/plans/` and dispatch according to topology. All topologies use a **two-stage review** (spec compliance then code quality) -- adapted to the execution unit (task for A/B, agent for C).

   > **Known gap -- ralph-loop per-task prompt assembly is manual.**
   > The topologies below use the SDD model (fresh subagent per task). If you choose to use `/ralph-loop` for a specific convergence-heavy task instead, there is no skill that auto-generates the prompt from the task definition. You must write it by hand:
   > ```
   > /ralph-loop "Implement [paste task text from plan.md Tasks section].
   > Review criteria: [paste relevant items from ${REVIEW_STANDARDS}].
   > Output <promise>TASK DONE</promise> when all tests pass and checklist passes."
   > --completion-promise "TASK DONE"
   > ```
   > Use ralph-loop per-task only for iterative/convergence tasks where the agent needs multiple self-correction passes. For well-defined tasks, the SDD dispatch below is sufficient and handles review automatically.

   ### Topology A -- Single Agent (SDD execution model)

   Fresh subagent per task with two-stage review. The orchestrator never implements directly -- it dispatches.

   For each task in the plan:

   ```
   +-------------------------+
   | Dispatch Implementer    | <-- fresh Task agent (general-purpose)
   | (paste full task text +  |     with full task text + context
   |  architectural context)  |     (do NOT make it read the plan file)
   +-----------+-------------+
               |
        Questions? --yes--> Orchestrator answers, re-dispatches
               | no
               v
   Implementer: code -> test -> commit -> self-review -> report
               |
   +-----------v--------------+
   | Dispatch Spec Reviewer    | <-- fresh Task agent (general-purpose)
   | (task spec + implementer  |     Adversarial: "verify by reading code,
   |  report)                  |     not by trusting report"
   +-----------+--------------+
               |
        Issues? --yes--> Implementer fixes -> Spec Reviewer re-reviews (loop)
               | no
               v
   +---------------------------+
   | Dispatch Code Quality      | <-- fresh Task agent (code-reviewer)
   | Reviewer (git diff only)   |     BASE_SHA -> HEAD_SHA for this task
   +-----------+---------------+
               |
        Issues? --yes--> Implementer fixes -> Code Reviewer re-reviews (loop)
               | no
               v
   Mark task complete -> git commit -> next task
   ```

   **Prompt templates** (fill in bracketed sections and paste as Task agent prompt):
   - `./implementer-prompt.md` -- full task text + context, TDD, self-review before reporting
   - `./spec-reviewer-prompt.md` -- adversarial task-level spec verification
   - `./code-quality-reviewer-prompt.md` -- git SHA-scoped quality review (includes CWE + config sprawl)
   - `/domain-code-review` skill -- project-specific standards review (review-standards.md, env-config-policy, logging). Invoke after code-quality review passes.
   - If `${CONTEXT_DIR}/review-learnings.md` exists, include it in the reviewer dispatch prompt with instruction: "Apply any review instructions from entries applicable to your role."

   **Rules:**
   - Never dispatch code quality review before spec compliance passes
   - Never move to next task with open review issues
   - If implementer fails a task, dispatch a fix subagent -- don't fix manually (context pollution)

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

   ### Topology B -- Coordinated Sub-Agents (SDD per workstream)

   Same SDD execution model as Topology A, but **parallelized across independent workstreams**.

   1. Group tasks by workstream from the plan's parallelization markers
   2. For each workstream, launch an orchestrator Task agent that runs the Topology A loop internally (fresh implementer + two-stage review per task, sequential within the workstream)
   3. Independent workstreams run in parallel
   4. Main orchestrator waits for all workstreams to complete before RALPH finalization

   **Rules:**
   - No shared mutable state between workstreams
   - Each workstream reports: tasks completed, review outcomes, files changed
   - If a workstream fails, it doesn't block others -- main orchestrator handles the failure

   ### Topology C -- Agent Team (dedicated agent per role + spec review gate)

   Agent Team does NOT use SDD's fresh-subagent-per-task model -- each agent needs accumulated role context across its steps. Instead, use **dedicated agents with spec review gates**.

   ```
   +--------------------------+
   | Read specs/master-plan.md |
   | Build execution DAG       |
   +-----------+--------------+
               |
   For each agent in dependency order:
               |
   +-----------v---------------+
   | Verify inputs available    | <-- from prior agents' outputs or codebase
   | (I/O contract check)      |
   +-----------+---------------+
               |
   +-----------v---------------+
   | Launch dedicated Task agent| <-- full spec file as prompt
   | (preserves role context    |     Instructed to ONLY modify Files Owned
   |  across all its steps)     |     Executes all steps in its spec internally
   +-----------+---------------+
               |
   +-----------v---------------+
   | File ownership check       | <-- pre-run snapshot vs post-run snapshot
   | (CRITICAL: unauthorized    |     newly_changed must be subset of Files Owned
   |  file changes = restore +  |
   |  re-execute)               |
   +-----------+---------------+
               |
   +-----------v---------------+
   | Spec Compliance Review     | <-- fresh Task agent (general-purpose)
   | (agent's spec + outputs    |     Verifies: all declared outputs produced?
   |  vs actual implementation) |     All steps implemented? Nothing extra?
   +-----------+---------------+     Per-agent RALPH criteria pass?
               |
        Issues? --yes--> Re-launch agent to fix within its scope (loop)
               | no
               v
   +---------------------------+
   | Code Quality Review        | <-- fresh Task agent (code-reviewer)
   | (git diff for this agent's |     Reviews only this agent's changed files
   |  changed files)            |
   +-----------+---------------+
               |
        Issues? --yes--> Re-launch agent to fix (loop)
               | no
               v
   Agent validated -> proceed to downstream agents
   ```

   **Parallelization:** Agents with no mutual dependencies -> launch in parallel. Agents that consume another's output -> wait for producer to complete AND pass both reviews.

   **Integration step:** After all agents complete and pass reviews -> execute any integration steps from the master plan (wiring components, updating imports). Run spec + code quality review on integration changes too.

   **Prompt templates** for Agent Team:
   - `./agent-spec-reviewer-prompt.md` -- agent-level spec verification (outputs, steps, file ownership, RALPH criteria, boundaries)
   - `./code-quality-reviewer-prompt.md` -- same quality reviewer, scoped to agent's changed files

4. **Phase boundary gate** -- after all tasks in a plan phase complete, before starting the next phase:
   ```bash
   ${TEST_CMD} ${INTEGRATION_MARKERS}
   ```
   All tests must pass (0 failures, 0 errors) before proceeding. If tests fail at a phase boundary, apply the 3-Strike Error Protocol within the current phase -- do NOT start the next phase with a broken baseline.

5. **Update `progress.md` after each major milestone** -- log completed steps, files modified, errors encountered, and RALPH assessment results. For Agent Team topology, log per-agent completion status.

6. **Apply the 3-Strike Error Protocol:**
   - Attempt 1: Diagnose and fix
   - Attempt 2: Alternative approach
   - Attempt 3: Broader rethink
   - After 3 failures: Escalate to user
   - Log ALL attempts in `progress.md` Error Log (and the Errors Encountered section of `task_plan.md` for structured tracking)

7. **Mid-Execution Plan Change:** If the user requests a scope change during execution:
   - Pause execution -- do NOT continue with the stale plan
   - Update `progress.md` with what's completed so far
   - Branch the decision: minor tweak (edit plan in-place, note the amendment in `findings.md`) vs. significant change (return to Phase 3, re-generate and re-analyse)
   - Never silently absorb a scope change -- log it in `task_plan.md` Decisions Made table

8. **Subagent crash/timeout recovery (Topology A/B):** If a subagent (implementer, reviewer) fails to return or errors out:
   - Use the **Context Recovery Protocol** (see below) -- planning-with-files restores session state
   - Check `git status` and `git log -3` to see what the subagent committed before crashing
   - Re-dispatch a fresh subagent with the remaining work -- do NOT retry blindly from scratch
   - Log the crash in `progress.md` Error Log with what was recovered

9. **Agent crash recovery (Topology C only):** If a dedicated agent fails or times out mid-run:
   - Use the **Context Recovery Protocol** to restore orchestrator state
   - Check `git log --oneline -10` and `git diff --stat` to identify which steps the agent completed before crashing
   - Run the **file ownership check** on any files the agent touched -- if unauthorized changes exist, restore from the pre-agent snapshot (`git checkout <PRE_AGENT_SHA> -- <file>`) before re-launching
   - Re-launch the agent with an explicit "start from step N" instruction listing only the remaining unfinished steps -- do NOT re-run completed steps
   - Re-run spec compliance review on ALL steps the re-launched agent executes, including those it inherited from the crashed run (partial work may be inconsistent)
   - Log the crash in `progress.md` with: which steps completed, which were partial, what was restored

10. **RALPH Finalization Loop:**

    **Pass criteria** -- ALL must be green before halting:
    - Integration tests: 0 failures, 0 errors
    - Linter: 0 violations (if `LINT_CMD` is set)
    - Code-quality reviewer: Assessment = "Approved" or "Approved with minor issues" (no open CRITICAL issues)
    - Every RALPH criterion in `${PLAN_DIR}/*.md`: explicitly assessed as met

    Delegate convergence to the `ralph-loop` plugin:
    ```
    /ralph-loop "Run the full validation suite:
      1. ${TEST_CMD} ${INTEGRATION_MARKERS}  (0 failures, 0 errors required)
      2. ${LINT_CMD}  (0 violations required)
      3. Dispatch code-quality-reviewer on the full diff since branch start.
         Assessment must be Approved or Approved with minor issues, no open CRITICAL issues.
      4. Assess every RALPH criterion in ${PLAN_DIR}/*.md against the current code.
    If ALL pass, output <promise>ALL_CRITERIA_GREEN</promise>.
    If any fail, diagnose and fix. For task-level fixes, dispatch a fresh subagent -- do not fix inline."
    --completion-promise "ALL_CRITERIA_GREEN"
    --max-iterations 5
    ```

    **Escalation:** If `ALL_CRITERIA_GREEN` is not reached within 5 iterations, ralph-loop stops automatically. Review the remaining failures and escalate to the user.

    **For Agent Team (Topology C):** After the RALPH loop passes on each agent's scope, run a final cross-agent check -- verify no agent regressed another agent's RALPH criteria.

11. **Update `progress.md`:** Log RALPH results table (each criterion: met/failed/escalated), loop iterations, topology execution summary.

## Phase 6: Finalization

**Goal:** Post-execution gates ensuring security, config hygiene, domain correctness, and documentation accuracy.

1. **Re-read `task_plan.md`** -- confirm all prior phases are complete.

2. **Security check** (if `SECURITY_CMD` is set):
   ```bash
   ${SECURITY_CMD}
   ```
   Alternatively, review code-quality-reviewer outputs for CWE flags.
   Flag any CWE-listed vulnerabilities for **immediate fix** -- do not defer.

3. **Config sprawl check** (if `ENV_CONFIG_POLICY` exists):
   - Apply policy from `${ENV_CONFIG_POLICY}`
   - Verify: all new config uses python-dotenv pattern (or project-appropriate config mechanism)
   - Verify: no secrets in code or committed .env files
   - Verify: module-specific config in module directory (not root), if applicable
   - Verify: new config keys documented in module README.md

4. **Domain review** (skip for infra/config-only changes):
   Invoke `/domain-code-review` skill on the full branch diff. This skill reads `${REVIEW_STANDARDS}`, `${ENV_CONFIG_POLICY}`, and the `logging:` config block, then dispatches a reviewer subagent.
   - If `DOMAIN_REVIEWER` is also set, dispatch that agent too (it may have domain-specific criteria beyond what review-standards.md covers)
   - CRITICAL findings must be fixed before PR; Important findings require acknowledgment

5. **Consolidate review findings across all Phase 5 iterations:**

   **Timing:** This happens once, here at Phase 6 (feature completion) -- not per-task or per-phase. During Phase 5 execution, reviewer outputs are logged to `progress.md` as they occur. Phase 6 is when you read back across all of them, look for patterns, and act.

   Collect all code-quality and spec-compliance reviewer outputs from every task/agent in Phase 5. Classify each finding by pattern:

   | Pattern | Action |
   |---------|--------|
   | **Systematic / structural** -- same issue class appeared in 2+ tasks | Add a new check item to `${REVIEW_STANDARDS}` so future review cycles catch it early |
   | **Integration assumption** -- agent made an incorrect assumption about how components connect | Update `INVARIANTS.md` with the corrected assumption; update `ARCHITECTURE.md` if the contract changed |
   | **Reviewer blind spot** -- code-quality reviewer missed a whole class of issue | Amend `./code-quality-reviewer-prompt.md` with the missed check |
   | **One-off bug** -- isolated to a single task, no pattern | No doc update needed; already fixed in code |

   **Promotion from review-learnings.md:**
   After classifying Phase 5 findings above, also process `${CONTEXT_DIR}/review-learnings.md`:
   - Entries (UG or AD) with 3+ task occurrences → promote to `${REVIEW_STANDARDS}` as a permanent review check
   - Move promoted entries to `## Promoted to Review Standards` section in review-learnings.md (do not delete — audit trail):
     ```markdown
     ### [UG-N] or [AD-N] <pattern name> — promoted YYYY-MM-DD
     ```
   - Reviewer blind spots identified via auto-detection → amend `./code-quality-reviewer-prompt.md` or `./spec-reviewer-prompt.md` as appropriate

   This feedback loop strengthens future reviews -- the reviewer agents read `${REVIEW_STANDARDS}` and `./code-quality-reviewer-prompt.md` directly, so improvements here propagate immediately.

6. **Documentation gates (create-or-update, multi-level):**

   **a. Module-level documentation validation:**
   List all modules and sub-modules touched by this feature (from the plan's "Files to touch" across all tasks). For each:
   - Verify `README.md` exists in the module directory -- if missing, create it (purpose, usage, key files/classes, dependencies)
   - Verify `ARCHITECTURE.md` exists for modules with non-trivial design (multiple components, data flow, abstractions) -- if missing, create it (design decisions, data flow, component interactions)
   - If either file exists but is stale relative to the changes made, update it to reflect current code

   **b. Integration-level documentation:**
   If the feature touched 2+ sub-modules under a common parent, verify the parent has documentation explaining how those sub-modules integrate. Create or update as needed.

   **c. Project-level documentation:**
   - Invoke `doc-lint` if available: audit broken refs, stale timestamps, code drift
   - Invoke `doc-sync` if available: apply corrections
   - Update project-root `ARCHITECTURE.md` if design changed at the system level
   - Update feature list (`Features.md`) if public API changed
   - Update `tech-debt.md`: add new debt identified during this feature; **remove or mark resolved any items that this feature addressed** -- tech-debt.md is not append-only
   - Invoke `claude-md-management:revise-claude-md` if changes affect project conventions

   **Note:** When `DOC_TASK_MODE=auto`, Phase 4 generates a mandatory documentation task that should have handled (a) and (b) during execution. Phase 6 is the **safety net** -- if the documentation task missed a module or was incomplete, catch it here before declaring the branch ready.

7. **Emit final summary:**
   - What was implemented (per task)
   - RALPH results table (final passing state)
   - Plan file path
   - Recommendation for follow-up work (if any)

8. **Offer branch completion options** -- invoke `superpowers:finishing-a-development-branch` if available.

## Context Recovery Protocol

If the context window compresses or you `/clear` mid-session:

1. Run the session-catchup script (see Session Recovery above) -- planning-with-files restores session state from disk
2. Run `git diff --stat` and `git log --oneline -10` to see recent changes
3. Resume from the last incomplete phase

This is the primary advantage of this unified skill -- the planning files make you crash-resistant.

## Rules

- **Never skip Phase 2 research** to jump straight to planning -- findings.md is the foundation
- **Never re-explore the codebase in Phase 3** when findings.md already has the answer
- **Never use `task_plan.md` as the implementation plan** -- that's `docs/plans/*.md`
- **Never proceed from Phase 3 to Phase 4 without user approval** on the generated plan
- **Never proceed from Phase 4 to Phase 5** without tasks appended to the plan file
- **Always apply the 2-Action Rule** during research -- write findings to disk after every 2 reads/searches
- **Always update `progress.md`** after major milestones -- this is your session insurance
- **`superpowers:brainstorming` in Phase 1 is intentional** -- it is explicitly invoked by user choice, not an auto-trigger. Do not suppress it. However, if superpowers skills auto-trigger during Phases 2-6, follow plan-and-execute protocol instead. Do not follow the superpowers flow in parallel -- it creates a duplicate dispatch loop.
- **Do not re-run plan analysis** in Phase 5 -- the plan was already validated in Phase 3.
- **Tests must verify real behavior, not exist for count.** Every test must answer: "what business-level or functional behavior does this prove works?" Tests that merely exercise code paths, assert mocks were called, or restate the implementation are worthless. Reject them in review.

## Relationship to Individual Skills

| Want to... | Use |
|------------|-----|
| Full lifecycle: concept + research + plan + execute with context recovery | **This skill (`/plan-and-execute`)** |
| Structured design exploration before spec | `superpowers:brainstorming` (invoked via Phase 1 Path A or B) |
| Spec traceability (new module / formal feature) | `speckit:specify` (invoked via Phase 1 Path A or C, or Phase 3 speckit gate) |
| Lightweight context tracking without formal planning | `planning-with-files` directly |
| Iterative convergence on a single task | `ralph-loop` plugin directly |
| Project-specific standards review | `/domain-code-review` (standalone, or invoked by Phase 5/6) |
| Domain review for project modules | `${DOMAIN_REVIEWER}` agent directly (if configured) |
