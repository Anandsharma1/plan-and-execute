# Spec: v2 — Thin Orchestrator + Bounded Skills

**Status:** Draft (2026-04-19)
**Predecessor:** `docs/specs/harness-improvements-generic-vs-pluggable.md` (v1, implemented 2026-04-18)
**Source analysis:** Review of MediMigration's 10 generalizable harness skills; feedback from two independent review agents on v1's architectural gap.

---

## 1. What v1 Got Wrong

v1 improved enforcement (phase guard, review preamble, RCA fields, promotion gate) but added each improvement as inline prose inside `SKILL.md`. The result is a larger monolith. The structural pattern that makes MediMigration's harness maintainable — thin orchestrator + bounded specialist skills with explicit contracts — was not preserved.

Specifically:
- Review-context compilation is inline in Phase 5 prose
- Retrospection (RCA capture) is inline in Phase 6 prose
- Promotion gate logic is inline in Phase 6 prose
- The plan-analyser is a template used to construct a prompt, not a skill
- There is no validator extension point — projects cannot plug in validators

Additionally, v1 incorrectly dismissed MediMigration's 10 harness skills as domain-specific. They are all fully generalizable. The `mg-*` application skills are domain-specific; the harness skills are not.

---

## 2. Responsibility Matrix (the missing structural rule)

Without an explicit rule, future additions keep landing in SKILL.md. This matrix defines the rule:

| Layer | Responsibility | Must NOT do |
|-------|---------------|-------------|
| **Orchestrator** (SKILL.md) | Phase sequencing, user approval gates, dependency detection, fallback policy, topology choice, dispatch routing, state transitions | Implement review logic, implement retrospection, implement promotion logic, implement validation |
| **Control skills** (plan-analyser, task-compiler) | Artifact evaluation and generation with explicit input/output contracts | Know about orchestrator state, write to tracking files |
| **Validator skills** (wiring-auditor, etc.) | Own exactly one risk class each; pass/fail verdict with evidence | Know about other validators, implement multi-risk checks |
| **Learning-loop skills** (retrospect-execution, policy-updater) | Capture misses and evolve policy; own the review-learnings.md and review-standards.md lifecycle | Dispatch agents, make execution decisions |
| **Compiler-context skills** (review-context-compiler) | Transform artifacts into bounded, role-filtered context packets for downstream consumers | Make policy decisions, do evaluation |

This matrix is the single structural rule. When adding new behavior, assign it to a layer first. If it doesn't fit cleanly, the layer boundary is wrong — fix the boundary, don't stuff the behavior into the orchestrator.

---

## 3. Changes to Implement

### FR-8: Document the responsibility matrix

**What:** Add the matrix above to `HELP.md` as a first-class section ("Skill Decomposition Model"). Reference it from `SKILL.md` architecture section.

**Why:** Without this, the next implementer will default to SKILL.md for everything. The matrix is the only durable guardrail.

**Scope:** HELP.md + SKILL.md architecture section. ~25 lines.

---

### FR-9: Promote plan-analyser from template to skill

**What:** Convert `templates/plan-analyser-prompt.md` into a proper skill at `.claude/skills/plan-analyser/SKILL.md` inside the P&E repo (or dispatched as `agent-plan-analyser.md` in the consumer project, seeded by install.sh).

**Current state:** A template file that the orchestrator uses to construct a prompt for `Agent()`. Not user-invokable. Not testable in isolation.

**Target state:**
- Skill file with explicit frontmatter (`name: plan-analyser`, `user-invokable: true`)
- Input contract:
  - `PLAN_FILE`: path to plan.md
  - `SPEC_FILE`: path to spec.md (optional)
  - `FINDINGS_SUMMARY`: extracted Technical Decisions + Requirements sections
  - `RESOLVED_CONFIG`: parameter values affecting plan validity
  - `RELEVANT_FILES`: explicit file list the plan touches
- Output contract:
  - Dimension table (7 dimensions, pass/concern/blocker)
  - Summary verdict: PROCEED | PROCEED WITH CHANGES | BLOCK
  - Expanded concerns/blockers with suggested fixes
- Standalone invocable: `/plan-analyser PLAN_FILE=docs/plans/foo.md` for reviewing a plan without running the full lifecycle

**Orchestrator change:** Phase 3 replaces the prompt-construction step with `Skill("plan-analyser", ...)` invocation. The template remains as the authoritative criteria source (referenced by the skill, not duplicated).

**Why:** A template can't be tested, versioned, or invoked independently. A skill can.

---

### FR-10: Extract review-context-compiler as a skill

**What:** Extract the pre-dispatch digest compilation (currently described as 5-step inline prose in Phase 5) into a skill.

**Responsibility:** Given a path to `review-learnings.md` and a reviewer role, produce a bounded, role-filtered, severity-sorted digest capped at 15 entries.

**Input contract:**
- `REVIEW_LEARNINGS_FILE`: path to review-learnings.md
- `ROLE`: `spec-reviewer` | `code-quality-reviewer` | `domain-reviewer`
- `CAP`: max entries (default 15)

**Output contract:**
- A markdown digest block, ready to inject above the reviewer prompt
- Format: entries sorted by severity (critical first), then recency; promoted entries excluded; role-irrelevant entries excluded

**Orchestrator change:** Phase 5 dispatch steps replace inline digest prose with `Skill("review-context-compiler", ROLE=..., ...)`. The output is injected at the top of each reviewer prompt.

**Why:** The current inline prose leaves room for the orchestrator to skip, abbreviate, or misapply the digest. A skill with an explicit output contract makes it verifiable.

**Skill location:** `.claude/skills/review-context-compiler/SKILL.md` in P&E repo (seeded into consumer project by install.sh, or invoked from P&E skills directory).

---

### FR-11: Extract retrospect-execution as a skill

**What:** Extract Phase 6's RCA capture step into a standalone skill.

**Responsibility:** Given evidence of what happened during a task/phase, classify defects into structured RCA records and append them to `review-learnings.md`.

**Input contract:**
- `TASK_ID`: task being retrospected
- `REVIEWER_FINDINGS`: the raw findings from spec + code quality + domain reviewers
- `REVIEW_LEARNINGS_FILE`: path to review-learnings.md (append target)
- `PROMOTION_THRESHOLD`: from project-config.yaml

**Output contract:**
- Zero or more new AD-N or UG-N entries appended to `review-learnings.md`
- Each entry has full RCA fields: Symptom, Root-cause, Detection-gap, Prevention, Occurrences, Severity
- Summary: how many new entries added, how many existing entries incremented

**Orchestrator change:** Phase 6 step for "capture misses" becomes `Skill("retrospect-execution", TASK_ID=..., ...)` instead of inline prose.

**Standalone use:** `/retrospect-execution` — run retrospection on a completed task outside the full lifecycle. Useful after ad-hoc fixes or hotfixes.

**Why:** Keeping retrospection inside Phase 6 prose means it gets skipped or abbreviated when the orchestrator is under context pressure. A skill with an explicit append contract is auditable.

---

### FR-12: Extract policy-updater as a skill (replaces inline Phase 6 promotion gate)

**What:** Extract Phase 6's promotion gate logic into a skill that manages the review-learnings.md → review-standards.md lifecycle.

**Responsibility:** Given the current review-learnings.md, present qualified entries for promotion (or emit a headless bundle), and on user decision, move approved entries into review-standards.md.

**Input contract:**
- `REVIEW_LEARNINGS_FILE`: path to review-learnings.md
- `REVIEW_STANDARDS_FILE`: path to review-standards.md
- `PROMOTION_THRESHOLD`: min occurrences for recommendation
- `SEVERITY_OVERRIDE_PROMOTION`: severities that recommend at 1 occurrence
- `GATE_MODE`: `interactive` | `headless`

**Output contract:**
- `interactive` mode: presents promotion table, waits for user decisions, writes approved entries to review-standards.md, marks promoted entries in review-learnings.md
- `headless` mode: writes `promotion-bundle.md` listing qualified entries with recommended actions; does NOT write to review-standards.md; sets `needs-policy-decision` status

**Orchestrator change:** Phase 6 promotion gate becomes `Skill("policy-updater", GATE_MODE=${PROMOTION_GATE_MODE}, ...)`.

**Standalone use:** `/policy-updater` — run the promotion gate independently (e.g., at end of sprint after multiple feature runs).

**Why:** Splitting "capture misses" (FR-11) from "promote policy" (FR-12) makes both auditable and independently runnable. The inline Phase 6 gate conflates them.

---

### FR-13: Validator extension point

**What:** Define a pluggable validator interface so consumer projects can add validators that run automatically during Phase 5 task review gates.

**Design principle:** The orchestrator decides *which* validators to route to (based on task risk tags or explicit config); each validator owns one risk class and returns a pass/fail verdict with evidence.

**Validator contract (schema):**

```yaml
# .claude/validators/<name>/SKILL.md
name: <validator-name>
description: <one-sentence responsibility — what risk class does this own?>
type: validator
input:
  task_id: string        # task being validated
  owned_files: [string]  # files the task touches
  context: string        # relevant task contract text or findings
output:
  verdict: pass | fail | skip
  evidence: string       # specific file/line proof or "no issues found"
  gaps: [string]         # list of specific gaps (empty if pass)
```

**Invocation surface:**
- Orchestrator calls validators in Phase 5 after each task's code quality review gate
- Routing driven by task risk_tags (if present) or `VALIDATORS` param in project-config.yaml
- Each validator dispatched as fresh subagent: `Agent(subagent_type="general-purpose", prompt=<skill content + task context>)`
- Verdict injected into task review summary

**Built-in validators (shipped with P&E, all optional, off by default):**

| Validator | Risk class | Enable via |
|-----------|-----------|-----------|
| `wiring-auditor` | Dead code / unwired paths | `VALIDATORS: [wiring-auditor]` |
| `contract-auditor` | Cross-layer data contract drift | `VALIDATORS: [contract-auditor]` |
| `failure-path-auditor` | Exception handling / state-transition safety | `VALIDATORS: [failure-path-auditor]` |
| `mutation-site-auditor` | Partial refactors / field mutation consistency | `VALIDATORS: [mutation-site-auditor]` |
| `evidence-verifier` | Optimistic "done" claims without evidence | `VALIDATORS: [evidence-verifier]` |

**Consumer extension:** Projects add their own validators at `.claude/validators/<name>/SKILL.md`. The orchestrator discovers them by reading the `VALIDATORS` list from project-config.yaml.

**Why now:** Without a defined extension point, validators can't be added cleanly. The contract schema locks in the interface before implementations proliferate.

---

### Cleanup: README / HELP split

**Problem:** Both files describe what the skill does and list dependencies. HELP.md has `"Language focus: Python"` which is wrong for a generic layer.

**Rule:**

| File | Audience | Content |
|------|----------|---------|
| `README.md` | GitHub visitors | What it is, install (all platforms), quick start, "How it works" diagram, Getting Started 3 steps, phase overview table, dependencies (brief), acknowledgements |
| `HELP.md` | Practitioners in-session | Parameters, config format, Three-R contract, Skill Decomposition Model (FR-8 matrix), known overlaps, settings.json vs local, domain code review surfaces |

**Changes:**
- Remove "What It Does" and "When to Use It" sections from HELP.md (they belong in README)
- Remove `"Language focus: Python"` from HELP.md (project-layer config, not generic)
- README.md already covers install + quick start + phase overview — no new content needed there
- Add FR-8 responsibility matrix to HELP.md

---

## 4. What This Does NOT Include

- `task-compiler` as a separate skill — Phase 4's task breakdown is already lightweight and user-facing (the user sees and approves the task list). Extracting it would add a skill boundary with no clear benefit for current consumers. Revisit when Phase 4 grows.
- `implement-plan` as a separate skill — Phase 5 execution IS the orchestrator's core loop. Extracting it would just rename SKILL.md's execution section. Not worth it until the orchestrator is thin enough to make the split meaningful.
- Built-in validators enabled by default — too noisy for projects that haven't configured them. All validators are opt-in via `VALIDATORS` list.
- JSON artifact format for review-learnings.md — markdown is sufficient. The skills operate on structured markdown (RCA field headers), not JSON. Add machine-readable format only if a consumer requests it.

---

## 5. Implementation Order

| Step | Change | Dependency | Effort |
|------|--------|-----------|--------|
| 1 | FR-8: Responsibility matrix in HELP.md | None | Tiny |
| 2 | Cleanup: README/HELP split | None | Small |
| 3 | FR-9: plan-analyser skill | Templates already exist | Small |
| 4 | FR-10: review-context-compiler skill | None | Small |
| 5 | FR-11: retrospect-execution skill | None | Medium |
| 6 | FR-12: policy-updater skill | FR-11 | Medium |
| 7 | FR-13: Validator extension point + built-in validators | FR-9 (pattern) | Medium |
| 8 | Thin SKILL.md orchestrator (replace inline prose with Skill/Agent calls) | FR-9 through FR-12 done | Medium |

Steps 1-4 are independent and can be parallelized. Steps 5-6 are sequential. Steps 7-8 can start after step 3 establishes the pattern.

---

## 6. New File Map

```
.claude/skills/
  plan-analyser/
    SKILL.md          — 7-dimension plan critique (promoted from templates/)
  review-context-compiler/
    SKILL.md          — pre-dispatch digest compiler
  retrospect-execution/
    SKILL.md          — RCA capture → review-learnings.md
  policy-updater/
    SKILL.md          — promotion gate → review-standards.md

.claude/validators/           ← new directory
  wiring-auditor/
    SKILL.md          — dead code / unwired path validator
  contract-auditor/
    SKILL.md          — cross-layer contract drift validator
  failure-path-auditor/
    SKILL.md          — exception / state-transition validator
  mutation-site-auditor/
    SKILL.md          — field mutation consistency validator
  evidence-verifier/
    SKILL.md          — evidence completeness validator

templates/
  plan-analyser-prompt.md   ← keep as authoritative criteria source
                              (skill references it; does not duplicate it)
```

`SKILL.md` (orchestrator): all inline implementation prose replaced by `Skill(...)` or `Agent(...)` calls. Phase step descriptions become 3-5 lines: what to dispatch, what input to provide, what to do with output. No logic.
