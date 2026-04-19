# Codex Adoption Playbook

**Status:** Analysis artifact  
**Date:** 2026-04-19  
**Scope:** How to adopt `plan-and-execute` as a real Codex workflow without redoing the current architecture review.

---

## 1. Executive Summary

`plan-and-execute` is now in a materially better state for Codex adoption than it was during the first review pass.

The strongest reusable asset is no longer just the rules. It is the **workflow shape**:

- thin orchestrator
- bounded specialist skills
- structured JSON artifacts
- explicit validator extension point
- review-context compilation before reviewer dispatch
- retrospection and policy promotion as separate operations

If Codex adoption happens later, preserve that shape. Do **not** collapse the system back into one large Codex-only orchestrator skill.

The right migration model is:

1. keep the **assistant-neutral workflow core**
2. add a **Codex adapter layer**
3. keep **project-specific content** pluggable

---

## 2. Current State Snapshot

This playbook assumes the repo state after the following changes landed:

- v1 generic/pluggable harness improvements
- v2 thin orchestrator + bounded skills decomposition
- JSON artifact switch (`defects.jsonl`, `policies.json`, `critic.json`, `promotion-bundle.json`)

The current reusable core already includes:

- `SKILL.md` as orchestrator
- `plan-analyser`
- `review-context-compiler`
- `retrospect-execution`
- `policy-updater`
- built-in validators:
  - `wiring-auditor`
  - `contract-auditor`
  - `failure-path-auditor`
  - `mutation-site-auditor`
  - `evidence-verifier`
- deterministic artifact schemas in `templates/defects-schema.md`

The current repo also ships mirrored platform folders, including `.codex/skills/...`. Those mirrored copies are useful packaging, but they should be treated as **distribution artifacts**, not proof that the workflow is already fully Codex-native.

---

## 3. What Is Already Portable

These parts should be treated as assistant-neutral and preserved as-is or with only light wording changes:

### 3.1 Workflow topology

- thin orchestrator
- bounded skill contracts
- validator extension point
- separate retrospection and policy-promotion steps

### 3.2 Artifact model

- `task_plan.md`
- `findings.md`
- `progress.md`
- `.claude/defects.jsonl`
- `.claude/policies.json`
- `.claude/critic.json`
- `promotion-bundle.json`

The specific **schemas** are reusable even if the paths later change.

### 3.3 Review model

- review preamble
- role-filtered defect digest via `review-context-compiler`
- domain review as a separate surface
- promotion gate instead of silently mutating reviewer policy

### 3.4 MediMigration lesson that must survive

The important lesson from `MediMigration` is structural:

- the orchestrator coordinates
- critics/validators evaluate
- learning-loop skills evolve the rules

That lesson has now been carried into `plan-and-execute`. Codex adoption should preserve it.

---

## 4. What Is Still Claude-Shaped

These are the areas that should be treated as adapter concerns, not core workflow concerns.

### 4.1 Claude-specific project-layer paths

The current project layer is scaffolded under `.claude/`:

- `.claude/project-config.yaml`
- `.claude/shared/review-preamble.md`
- `.claude/agents/domain-reviewer.md`
- `.claude/validators/...`
- `.claude/settings.json`

This is fine for Claude-first usage, but it is vendor-shaped.

### 4.2 Claude-specific instruction surfaces

- `CLAUDE.md` as the place for agent dispatch discipline
- `.claude/settings.json` Stop-hook registration
- wording built around Claude Task/Agent dispatch

### 4.3 Claude ecosystem dependencies

The workflow still names Claude-oriented integrations:

- `planning-with-files`
- `superpowers`
- `speckit`
- `ralph-loop`
- `claude-md-management`

Some are conceptually portable. Their **integration surfaces** are not.

---

## 5. Core Recommendation For Codex

Treat Codex adoption as an **adapter project**, not a harness rewrite.

The stable boundary should be:

### Layer 1 — Assistant-neutral core

- phase model
- artifact schemas
- skill contracts
- validator contracts
- review stack design
- promotion gate rules

### Layer 2 — Assistant adapter

- how skills are invoked
- how subagents are dispatched
- where shared instructions live
- how setup writes project files
- how phase-guard enforcement is implemented

### Layer 3 — Project layer

- domain rules
- invariants
- env/config policy
- review escape classes
- optional project validators

If the boundary is drawn this way, Claude and Codex can share the same workflow core.

---

## 6. Recommended Path Strategy

There are two viable ways to handle the current `.claude/*` project-layer paths.

### Option A — Low-risk first port

Keep the existing `.claude/*` paths for the first working Codex adoption.

Use Codex to run the workflow, but continue reading/writing:

- `.claude/project-config.yaml`
- `.claude/shared/review-preamble.md`
- `.claude/validators/...`
- `docs/review-standards.md`

#### Why this is the best first move

- smallest diff
- easiest parity check against Claude behavior
- avoids a path migration and a runtime migration at the same time
- preserves compatibility with existing consumers

#### Drawback

The resulting Codex workflow is operationally fine but still visually Claude-branded.

### Option B — Assistant-neutral path migration

After behavior parity is proven, move the project layer to assistant-neutral locations such as:

- `.ai/project-config.yaml`
- `.ai/shared/review-preamble.md`
- `.ai/validators/...`
- `AGENTS.md` for shared agent-dispatch rules

#### Why this is better long-term

- no vendor leakage in persistent project state
- cleaner multi-assistant story
- easier future support for Codex + Claude + others

#### Why this should not be step 1

It combines path migration, setup migration, and runtime migration in one change. That is unnecessary risk.

### Recommendation

Use **Option A first**, then decide whether Option B is worth the churn once Codex parity exists.

---

## 7. Codex Surface Mapping

This is the concrete mapping to use when the work starts.

| Claude-shaped surface | Codex adoption guidance |
|---|---|
| `.claude/skills/plan-and-execute/` | Keep shipping `.codex/skills/plan-and-execute/` as the Codex distribution surface |
| `.claude/skills/domain-code-review/` | Keep shipping `.codex/skills/domain-code-review/` as the sibling review skill |
| `CLAUDE.md` dispatch-discipline block | Mirror the same rules into `AGENTS.md` or another Codex-visible instruction file |
| `.claude/agents/domain-reviewer.md` | Do not force a file-based agent abstraction on Codex. Prefer invoking `domain-code-review` as the domain-review surface |
| Claude Task/Agent prompt wording | Translate to Codex execution semantics explicitly; do not assume wording ports itself |
| `.claude/settings.json` Stop hook | Treat as adapter-specific hardening. Do not block the first Codex adoption on hook parity |

Two important rules:

1. The **domain-review capability** matters more than the exact Claude named-agent shape.  
2. The **phase guard** is useful, but lack of a Codex-equivalent hook should not block the first working port.

---

## 8. What Codex Adoption Should Preserve Exactly

These behaviors should be treated as non-negotiable.

### 8.1 Preserve bounded skill contracts

Do not re-inline:

- plan analysis
- review-context compilation
- retrospection
- policy promotion
- validators

### 8.2 Preserve JSON artifact contracts

Do not revert to markdown-only learning ledgers.

`defects.jsonl` and `policies.json` are one of the strongest improvements over the earlier state because:

- filter/sort is deterministic
- promotions are auditable
- digests are machine-derivable
- headless mode is possible

### 8.3 Preserve reviewer posture

Codex adoption must still include:

- review preamble
- defect digest injection
- adversarial verification posture
- no trusting implementer reports

### 8.4 Preserve the learning loop

Codex adoption is incomplete if it can implement and review tasks but cannot:

- append structured retrospection records
- compile role-filtered review context
- run the promotion gate

---

## 9. Where Codex-Specific Work Is Actually Needed

This is the real work list.

### 9.1 Dispatch semantics

Current skill text still assumes Claude-shaped dispatch language in places.

Codex adoption needs an explicit Codex dispatch model for:

- plan analysis
- task implementation
- spec review
- code-quality review
- validator runs
- domain review

The important thing is not the exact API call. The important thing is that the Codex adapter preserves:

- fresh-context review passes where intended
- clear input contracts
- explicit result handoff back to the orchestrator

### 9.2 Setup/init experience

The current `install.sh` and setup flow write Claude-shaped project files.

For Codex, decide whether the initial port will:

- keep writing the `.claude/*` project layer, or
- introduce `.ai/*` / `.codex/*` project-layer paths

Do not leave this implicit.

### 9.3 Shared instructions

`CLAUDE.md` currently carries important dispatch discipline.

Codex adoption needs a canonical answer to:

- where do these instructions live for Codex?
- which file is authoritative?
- how does setup append/update them?

If no answer exists, subagent behavior will drift.

### 9.4 Phase guard enforcement

The current guard is Claude-hook oriented.

Codex adoption should explicitly choose one of:

- no hard hook in v1 Codex port; rely on in-skill phase checks only
- external wrapper / shell-level enforcement
- future Codex-native hook if a stable surface exists

Recommendation: do **not** make hook parity a prerequisite for the first Codex port.

### 9.5 Dependency strategy

Each current dependency needs a Codex stance:

| Dependency | Codex guidance |
|---|---|
| `planning-with-files` | Replace with direct file writes or a Codex-native planning helper |
| `superpowers` | Treat as unavailable unless a Codex equivalent exists |
| `speckit` | Keep as optional external dependency only if invocation works in Codex; otherwise use manual path |
| `ralph-loop` | Keep optional; Codex should degrade gracefully without it |
| `claude-md-management` | Replace with direct file update flow or drop from Codex path |

The existing missing-dependency policy is good. Reuse it.

---

## 10. Recommended Implementation Sequence

When Codex adoption starts, use this order.

### Stage 1 — Behavior-preserving Codex port

- keep current artifact schemas
- keep current skill decomposition
- keep `.claude/*` project-layer paths
- wire `.codex/skills/...` as the actual Codex execution surface
- explicitly adapt dispatch wording and orchestration calls for Codex
- run without hook parity if necessary

**Goal:** prove end-to-end workflow parity before path cleanup.

### Stage 2 — Codex-native project experience

- decide whether to keep `.claude/*` paths or move to assistant-neutral paths
- mirror agent-dispatch discipline into Codex-visible instructions
- build Codex-specific setup/bootstrap flow if needed

**Goal:** remove unnecessary Claude-shaped UX from the Codex path.

### Stage 3 — Optional hardening

- better phase-guard enforcement for Codex
- Codex-specific install docs
- Codex-specific convenience wrappers
- better non-Claude dependency fallbacks

**Goal:** improve ergonomics, not architecture.

---

## 11. Acceptance Criteria For A Real Codex Adoption

Do not call the work complete unless all of these are true.

### Workflow parity

- a real feature can run end-to-end in Codex
- Phase 3 uses `plan-analyser`
- Phase 5 uses `review-context-compiler`
- Phase 5 or 6 writes `defects.jsonl` via `retrospect-execution`
- Phase 6 runs `policy-updater`

### Review parity

- Codex reviewers read the review preamble
- Codex reviewers receive the defect digest
- domain review runs as a distinct review layer
- validators can run when configured

### Artifact parity

- `critic.json` includes stable `run_id`
- `defects.jsonl` records include stable `run_id`
- `promotion-bundle.json` works in headless mode
- promoted rules land in `review-standards.md`

### Structural parity

- the Codex path does not collapse specialist skills back into one monolith
- project-specific rules remain pluggable
- Codex-specific changes live in the adapter layer, not scattered through the core contracts

---

## 12. Anti-Patterns To Avoid

These are the failure modes to avoid when the work is picked up later.

### 12.1 Do not re-monolithize

Do not turn `plan-analyser`, `review-context-compiler`, `retrospect-execution`, `policy-updater`, and validators back into inline sections of one Codex skill.

### 12.2 Do not mix path migration with runtime migration unless necessary

Proving Codex behavior and migrating all persistent file paths at the same time is avoidable complexity.

### 12.3 Do not overfit to Claude named-agent files

What matters is the capability, not preserving `.claude/agents/domain-reviewer.md` exactly.

### 12.4 Do not block on hook parity

The first working Codex port should prioritize workflow correctness over perfect Claude-hook equivalence.

### 12.5 Do not throw away the JSON learning loop

That would discard one of the strongest improvements made during this harness evolution.

---

## 13. Recommended Starting Point When This Work Is Picked Up

If this activity is resumed later, start here:

1. Treat this document as the architectural baseline.
2. Keep the current v2 decomposition and JSON artifacts intact.
3. Implement a **behavior-preserving Codex adapter** first.
4. Delay assistant-neutral path migration until after one successful Codex feature run.

That sequence avoids redoing the core analysis that has already been completed.
