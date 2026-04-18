# Spec: Harness improvements — generic layer + pluggable project layer

**Status:** Implemented (2026-04-18). All FR-1 through FR-7 and §9.1 cleanup items landed on `main`. See git log for commit history.
**Target:** `Tooling/plan-and-execute` master
**Source analysis:** Comparison of fin-analyst (thin harness) vs MediMigration (heavy harness), cross-verified via CrossAI (Claude ↔ Codex debate, 2 rounds)
**Author handoff:** This document is written for an implementing agent working in the plan-and-execute repo. It contains the WHY (so you can make judgment calls on edge cases), the WHAT (concrete changes), and the NUANCES (where things bite). It also separates items that belong in the generic framework from items each consumer project adds on top.

---

## 1. Background

Two consumer projects were analyzed:

1. **`Vidai/MediMigration`** — a heavier harness with ~30 first-party skills, a mandatory `shared/review-preamble.md`, a Stop-hook phase-guard, a `.harness/runs/<id>/` JSON state directory, a defect registry, and a policy-promotion skill. This is our reference for "what a serious enforcement harness looks like."
2. **`StockMarket/fin-analyst`** — a thin harness that relies on `plan-and-execute` for orchestration, two custom reviewer agents, and a markdown-based `review-learnings.md` feedback loop. It has captured 7 auto-detected review patterns (AD-1…AD-7 covering hardcoded credentials, domain-layer import leaks, blocking sync I/O inside async methods, etc.) — **but none have been promoted to review-standards.md yet**, and an independent 10-agent review audit (`docs/CODE_REVIEW_CONSOLIDATED.md`) found 20+ hardcoded credentials still present in committed code, bare `except Exception` everywhere, and f-string logging violations across 50+ sites.

### 1.1 What the analysis found

**The problem is not missing reviewers — it is weak enforcement plus under-structured state.**

Specifically:
- fin-analyst's CLAUDE.md has a rule "NEVER skip Phase 6" but nothing enforces it.
- fin-analyst's `review-learnings.md` captures auto-detected patterns but the promotion gate keys on *3+ task recurrences* — a threshold that can be missed indefinitely if the same defect surfaces 20 times within one task (as in the consolidated review) instead of spreading across tasks.
- fin-analyst's reviewer agents exist but there is no `shared/review-preamble.md` forcing adversarial posture and escape-class enumeration into every dispatch.
- fin-analyst's `plan-and-execute` Phase 3 performs 7-dimension critical analysis **inline in the same agent that wrote the plan** (see fin-analyst's SKILL.md L327: *"This phase is self-contained — no external skills are called"*; L392: *"Analyse the plan — 7-dimension critical evaluation (inline, no external skill needed)"*) — a classic self-review bias.
- fin-analyst's code-quality hooks (ruff format/check, py_compile) live in `settings.local.json` (per-user, uncommitted), not the shared `settings.json`. So enforcement doesn't travel with the repo.

### 1.2 Design principle

Plan-and-execute should provide a **generic orchestrator + pluggable project layer**, not a one-size-fits-all workflow. The existing plug points already demonstrate this pattern:

| Existing plug point | Type | How project customizes |
|---|---|---|
| `REVIEW_STANDARDS` | path | Points to project's `docs/review-standards.md` |
| `ENV_CONFIG_POLICY` | path | Points to project's `docs/env-config-policy.md` |
| `DOMAIN_REVIEWER` | agent name | Project's domain-reviewer agent; `"none"` disables |
| `TEST_CMD`, `LINT_CMD`, `SECURITY_CMD` | shell command | Stack-specific |
| `PLAN_DIR` | path | Where plans live |
| `CONSTITUTION` | path | Optional speckit constitution |

This spec adds more plug points and makes the pattern explicit: **`project-config.yaml` declares paths and agent names; P&E loads them at runtime; reviewers/critics/hooks use whatever is configured.** The orchestrator itself stays domain-agnostic.

---

## 2. Changes to implement (generic, push to master)

Each change is labeled as a Feature Request (FR) for traceability.

### FR-1: Phase state file + Stop-hook phase guard

**Why:** The "Never skip Phase 6" rule in CLAUDE.md is LLM-voluntary. Consumer projects will occasionally halt after Phase 5 without running domain review / security check / docs gates. Need mechanical enforcement.

**Design:**

A single per-feature JSON state file tracks phase/status. A Stop hook reads it and blocks exit if a run is in progress but phase < closeout.

**State file:** `{CONTEXT_DIR}/.plan-and-execute.state.json`

```json
{
  "feature_slug": "persona-integration",
  "phase": 5,
  "status": "in_progress",
  "gates": {
    "phase_5": ["GATE:implementer_report", "GATE:tests_pass"],
    "phase_6a": [],
    "phase_6b": [],
    "phase_6c": []
  },
  "last_updated": "2026-04-18T08:45:00Z"
}
```

- `phase`: integer 0–6
- `status`: `"in_progress" | "complete" | "failed"`
- `gates`: optional map of gate IDs satisfied in each phase (populated as they pass)

**Hook:** `hooks/phase_guard.sh` (~30 lines)

```bash
#!/usr/bin/env bash
set -euo pipefail
STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.plan-and-execute.state.json"
[ -f "$STATE_FILE" ] || exit 0
python3 - "$STATE_FILE" <<'PY'
import json, sys
d = json.load(open(sys.argv[1]))
if d.get("status") == "in_progress" and int(d.get("phase", 0)) < 6:
    print(f"BLOCK: plan-and-execute run '{d.get('feature_slug')}' in phase {d.get('phase')} (status: in_progress). Phase must reach 6 (closeout).", file=sys.stderr)
    sys.exit(2)
sys.exit(0)
PY
```

**SKILL.md changes:** At every phase transition, write the state file. Approximately 10 scattered one-liners, e.g.:
```
Update .plan-and-execute.state.json: {feature_slug: ..., phase: 4, status: "in_progress", last_updated: <now>}
```

**install.sh changes:** Register the Stop hook in the consumer's `.claude/settings.json`. If the consumer already has a Stop hook (e.g., `.crossai/crossai_hook.py stop-check`), **append** the new hook to the array — do not overwrite.

**Nuances:**
- **No active run = no block.** If state file doesn't exist, exit 0 silently.
- **Complete runs.** On Phase 6 completion, set `status="complete"` and leave the file. Next run overwrites. The hook only blocks on `status=="in_progress"`.
- **Concurrent features.** Current design assumes one active run per working directory. If you want multi-feature parallelism, key the state on feature_slug and scan all `.plan-and-execute.state.*.json` files. Defer this unless a consumer needs it.
- **User override.** Document the escape hatch: set `status="failed"` manually to bypass the hook (for rescue scenarios). Do not invent a special env var.
- **Don't parse `task_plan.md` markdown checkboxes** — CrossAI flagged that as brittle. State file is the single source of truth.

**Acceptance:**
- [ ] Stop hook blocks when state file shows phase<6 and status=in_progress
- [ ] Stop hook exits 0 when no state file exists
- [ ] Stop hook exits 0 when status=complete regardless of phase
- [ ] State file is written on every phase transition per SKILL.md
- [ ] install.sh appends hook without clobbering existing Stop hooks

---

### FR-2: Phase 3 fresh-subagent critic dispatch

**Why:** Current Phase 3 runs the 7-dimension critical analysis inline in the planning agent — self-review bias. The critique should come from a fresh subagent with clean context so it evaluates the plan on its own merits.

**Design:**

**New template:** `templates/plan-analyser-prompt.md`
- Move the 7-dimension criteria currently in SKILL.md Phase 3 step 5 into this template
- Include: the plan file path, the 7 dimensions (scope clarity, negative-path coverage, topology validation, risk enumeration, codebase alignment, task boundary clarity, acceptance-criteria measurability), output format (`pass` / `concern` / `blocker` + per-dimension verdict)
- Include mandatory adversarial posture instructions (same as review-preamble — see FR-3)

**SKILL.md Phase 3 change:** Replace inline analysis with:
```
Step 5: Dispatch the plan analyser as a fresh subagent.

Agent(
  subagent_type="${PLAN_ANALYSER}",  # from project-config.yaml
  prompt=<compiled from templates/plan-analyser-prompt.md with plan path injected>,
  description="Independent plan analysis"
)

Read the analyser's structured verdict. If verdict=concern or blocker:
  - Amend the plan based on findings
  - Re-dispatch (max 3 iterations total)
  - If still concern after 3, present to user for manual override
```

**New plug point in project-config.yaml:**
```yaml
PLAN_ANALYSER: "general-purpose"   # or project-specific agent name; "none" disables
```

**Nuances:**
- **Clean context.** The analyser must receive ONLY the plan file path and codebase pointers — NOT the planning agent's chat history. Dispatch via the Agent tool; don't pass context.
- **Graceful degradation.** If `PLAN_ANALYSER="none"`, fall back to inline analysis (current behavior) with a warning logged to `progress.md`. Don't fail hard — some users may prefer inline for speed.
- **Convergence loop.** Cap iterations at 3. If still not converging, the plan probably has a deeper design problem — surface to user rather than auto-accepting.
- **Don't duplicate the full criteria in two places.** Source-of-truth is the template; SKILL.md links to it.
- **Known overlapping plugins.** `superpowers:writing-plans` and `superpowers:executing-plans` cover similar territory to P&E's planning + execution phases, but at a coarser grain. HELP.md should state explicitly: *"If this project uses plan-and-execute, do NOT additionally invoke `superpowers:writing-plans` or `superpowers:executing-plans` — P&E covers that workflow with more phases, review gates, and state tracking. Invoking both creates two parallel planning surfaces and drifts context across them."*

**Acceptance:**
- [ ] Phase 3 step 5 dispatches a fresh subagent when `PLAN_ANALYSER != "none"`
- [ ] Analyser receives plan file path, not orchestrator context
- [ ] Convergence loop iterates max 3 times
- [ ] Fallback to inline when `PLAN_ANALYSER="none"`
- [ ] `templates/plan-analyser-prompt.md` contains the 7-dimension criteria

---

### FR-3: Shared review-preamble — generic template + mandatory injection

**Why:** fin-analyst's reviewer agents (`finanalyst-reviewer.md`, `domain-reviewer.md`) read `docs/review-standards.md` — a 44k-word file — at dispatch time, and tend to skim. MediMigration's `.claude/shared/review-preamble.md` is ~60 lines of pointer-style adversarial checklist that every reviewer is *required* to read first. This injection pattern is what makes reviews actually adversarial.

**Design:**

**New template:** `templates/review-preamble-template.md` (~40 lines)

Structure (generic, verbatim-ready). Intentionally short — this is a pointer-and-posture file, NOT a rules catalog. The authoritative rules live in `${REVIEW_STANDARDS}`.

```markdown
# Review Agent Preamble

Every review subagent dispatched by plan-and-execute MUST begin by reading this file.

## Mandatory reads before reviewing

1. `${REVIEW_STANDARDS}` — project-specific review rules; authoritative escape-class catalog lives here
2. `${ENV_CONFIG_POLICY}` — env/config boundary rules
3. `review-learnings.md` — patterns captured in this feature's session

## Derive status from code, not prose

- Do NOT trust "Done" claims in the implementer's report
- Read the diff: `git diff <base>...HEAD`
- Verify every required behavior is reachable from a non-test runtime path
- Verify every "Must NOT" constraint is satisfied

## Adversarial enumeration

For every new public function / endpoint / flow, exercise and verify behavior for:

- empty collections
- missing artifacts
- already-completed entities
- concurrent mutations
- partial failures

Silent success on a no-op is a Critical finding.

> Dispatcher-side framing ("verify these claims, not confirm these changes"; no completion-report injection; adversarial prompt construction) is orchestrator responsibility — see `CLAUDE.md` → Agent Dispatch Discipline → Review prompt design. Do not restate those rules here.

## Project-specific escape classes

<!-- Project seeds this section from review-learnings.md AD-N entries.
     Keep to <20 lines. Link to review-standards.md for the full catalog. -->

## Output

Every review must produce:
- Critical / Important / Minor severity tags
- Approved / Changes-required verdict
- Critical and High findings block commit
- Map findings to plan must-haves (if plan exists)
```

The "Common escape classes" bullet list that previously lived here (wiring gaps / guard inheritance / bidirectional tracing / query-predicate uniqueness / config threading / canonical-list hardcoding / similar-pattern sweep) has been intentionally removed. It duplicates content that `templates/review-standards-template.md` already covers. Projects list these patterns in `${REVIEW_STANDARDS}`; the preamble points there.

**Injection wiring (the crucial part):**

Update all three reviewer dispatch points so the dispatcher prompt *begins* with:

> *"Before doing anything else, read `${REVIEW_PREAMBLE}` and follow every rule in it. The checklist below is additive, not a replacement."*

Affected files:
- `agent-spec-reviewer-prompt.md`
- `code-quality-reviewer-prompt.md`
- `domain-code-review/SKILL.md`
- SKILL.md Phase 5 reviewer-dispatch instructions

**New plug point:**
```yaml
REVIEW_PREAMBLE: ".claude/shared/review-preamble.md"   # optional; omit to disable
```

**`setup-prompt.md` change:** On first run, scaffold `.claude/shared/review-preamble.md` from the template. Leave the "Project-specific escape classes" section blank for the project to fill. If the project already has a `review-learnings.md`, offer to seed the project section from its top AD-N entries.

**Nuances:**
- **Short is the whole point.** If the template balloons past 100 lines, it defeats the purpose. Reviewers skim long prompts. Trim aggressively. Target 40 lines, hard cap 80.
- **Graceful degradation.** If `REVIEW_PREAMBLE` is unset or file missing, reviewers fall back to reading `${REVIEW_STANDARDS}` directly. Log warning to progress.md.
- **Don't duplicate review-standards.md.** The preamble *points* to sections of review-standards.md; it is not a summary. Overlap rots fast. The template deliberately omits an escape-class list to avoid drift with `templates/review-standards-template.md`.
- **Don't duplicate CLAUDE.md dispatcher rules.** Reviewer-side rules (what the reviewer does when running) live here. Dispatcher-side rules (how the orchestrator constructs reviewer prompts — "verify not confirm", no status injection, adversarial framing) live in FR-4's Agent Dispatch Discipline section. A single directional cross-reference keeps content in one place.
- **The injection is what makes it work.** Creating the file without updating the reviewer prompts is a no-op. CrossAI flagged this explicitly.
- **Reviewer must also read `review-learnings.md`.** The preamble mentions this, but Phase 5 dispatch should also include the file content (not just the path) in the reviewer prompt, so captured patterns influence the current review before the file is formally indexed.
- **HELP.md update required.** Add a short "Three review-R content contract" section to HELP.md so consumers understand the boundaries: **review-standards.md** = durable rule library; **review-learnings.md** = transient session AD/UG ledger that flows to standards via Phase 6 promotion; **review-preamble.md** = ≤80-line reviewer-action pointer, never a rules catalog.
- **Known overlapping plugin:** `superpowers:receiving-code-review` targets the implementer *receiving* review (how to respond to feedback); this FR targets the reviewer *doing* review. Complementary, different audiences. Document pairing in HELP.md.

**Acceptance:**
- [ ] `templates/review-preamble-template.md` exists and is <100 lines
- [ ] `setup-prompt.md` scaffolds the project preamble from template
- [ ] All three reviewer dispatch points inject the mandatory first-read instruction
- [ ] Missing preamble falls back to `REVIEW_STANDARDS` with logged warning
- [ ] Preamble references `review-learnings.md` for session-captured patterns

---

### FR-4: CLAUDE.md "Agent Dispatch Discipline" scaffolding

**Why:** MediMigration's CLAUDE.md contains rules learned from specific incidents (e.g., parallel agents wiping each other's work via git stash). These rules are fully generic — they apply to any project using Claude Code subagents. They should be scaffolded into new P&E consumer projects on first-run, not re-derived per-project.

**Design:**

**New template:** `templates/claude-md-agent-dispatch-discipline.md`

Contents (all generic, derived from MediMigration CLAUDE.md — verbatim-ready):

```markdown
## Agent Dispatch Discipline

### Parallel safety
- `isolation: "worktree"` does NOT reliably isolate file writes — parallel agents can still write to the main working directory. Observed incident: second agent ran `git stash` and wiped first agent's completed work.
- **Dispatch write-capable agents SEQUENTIALLY** — commit each agent's verified work before dispatching the next.
- **Read-only agents (reviewers, explorers, planners) CAN run in parallel.**

### Destructive git prohibition
Implementer subagent prompts MUST include verbatim:
> *"DO NOT run `git stash`, `git reset`, `git checkout`, `git clean`, `git restore`, or any destructive git command. Read-only git commands are fine."*

### Crash recovery
After subagent crash or rate-limit, run `git status` and `git diff --stat` before re-dispatching.
If diff is substantial and tests pass, work is likely done — cost of verifying (5–10 tool calls) is much lower than re-dispatching (100+).

### Review prompt design
Review prompts MUST be adversarial:
- Frame as "verify these claims," not "review these changes"
- Do NOT include the implementer's completion report in the reviewer prompt
- Reviewer derives status from code, not prose
- Include a concrete adversarial checklist (3+ scenarios)

### Fix-back rounds
When review finds a bug that escaped, the fix-back round MUST produce a structured RCA:
- **Symptom:** what went wrong observably
- **Root cause:** name the specific cognitive or process failure (not "be more careful")
- **Detection gap:** which review rule should have caught it
- **Prevention:** test/check/policy now guarding against regression

### Empirical verification
For bugs that depend on runtime semantics (async generators, DB transactions, LangGraph state, etc.), write a 20–30 line throwaway script that:
1. Reproduces the bug
2. Proves the fix works

Don't reason about runtime semantics — verify empirically.

### Mutation-test the guard
When you add a guard (test, invariant check, hook), mutate the invariant in place and verify the guard FAILS. A passing test after adding a guard is not evidence the guard works — it might be passing vacuously.
```

**`setup-prompt.md` change:** On first run, offer to append this section to the project's CLAUDE.md. Wrap with sentinel markers so re-runs can detect and update:

```markdown
<!-- BEGIN plan-and-execute:agent-dispatch-discipline -->
... content ...
<!-- END plan-and-execute:agent-dispatch-discipline -->
```

**Project-specific layer:** None. This is 100% generic.

**Nuances:**
- **Don't silently overwrite existing CLAUDE.md.** Always append, and check sentinel markers for existing install.
- **Re-install updates.** If template evolves (e.g., a new incident-lesson is added), re-running install.sh should update the bounded section only.
- **Order matters in CLAUDE.md.** Append at the end; don't interleave with existing sections.
- **Known overlapping plugin.** `claude-md-management:claude-md-improver` audits and rewrites CLAUDE.md over time. Document in HELP.md that claude-md-improver MUST respect the `<!-- BEGIN plan-and-execute:agent-dispatch-discipline -->` / `<!-- END ... -->` sentinel markers and not rewrite the bounded block. Reviewing consumers' CLAUDE.md history is a legitimate job for claude-md-improver outside the marked block.
- **Directional cross-reference with FR-3.** The "Review prompt design" sub-section here is the canonical home for dispatcher-side review framing ("verify not confirm", no completion-report injection, adversarial prompt construction). FR-3's preamble points here rather than restating. When this section evolves, the preamble does NOT need to change.

**Acceptance:**
- [ ] Template exists with the 6 rule sections above
- [ ] `setup-prompt.md` offers to append on first run
- [ ] Sentinel markers enable re-install to update without duplicating
- [ ] Never overwrites user content outside the sentinel block

---

### FR-5: Structured RCA fields in review-learnings template

**Why:** Current AD-N entries capture pattern name + review instruction but not the escape mechanics (why did it slip?). Without that, captured patterns don't convert into actionable controls. The 4-field RCA format (Symptom / Root-cause / Detection-gap / Prevention) is MediMigration's institutional discipline.

**Design:**

Update `templates/review-learnings-template.md` — extend the AD-N and UG-N comment blocks:

```markdown
### [AD-N] <pattern name>
- **Source:** Auto-detected across tasks T-X, T-Y
- **Issue type:** <category>
- **Symptom:** <what went wrong observably, with file:line citations>
- **Root cause:** <the cognitive or process failure — not "be more careful">
- **Detection gap:** <which review rule would have caught this>
- **Prevention:** <test/check/policy that now guards>
- **Review instruction:** <what reviewers should check for>
- **Applies to:** spec-reviewer | code-quality-reviewer | both
- **Occurrences:** <count; update on each re-surfacing>
- **Severity:** critical | important | minor
```

**SKILL.md Phase 5 change:** When auto-detecting a 2+ occurrence pattern, fill all fields. When user reports a gap (UG-N), prompt them for Symptom/Root-cause/Detection-gap/Prevention before appending.

**Migration note for existing consumers:** Projects with existing `review-learnings.md` (e.g., fin-analyst with AD-1…AD-7) won't have these fields. The Phase 6 promotion gate (FR-6) can backfill: when a pre-existing entry reaches the promotion threshold, prompt user to fill missing RCA fields before promoting. Do NOT batch-migrate silently — the fields require human judgment.

**Acceptance:**
- [ ] Template has new fields in comment block
- [ ] Phase 5 auto-detection fills fields
- [ ] Phase 5 user-reported gap flow prompts for fields
- [ ] Phase 6 promotion gate prompts for backfill on legacy entries

---

### FR-6: Phase 6 explicit promotion gate

**Why:** Current promotion logic is invisible — "3+ task occurrences → promote" is a rule written in prose with no mechanism to count, surface, or enforce it. CrossAI cross-review flagged this as a structural gap: in fin-analyst, AD-1 (hardcoded credentials) has been captured but never promoted despite the `CODE_REVIEW_CONSOLIDATED.md` finding 20+ instances. The 20 surfaced in one task, which doesn't satisfy "3+ task occurrences."

**Design:**

**SKILL.md Phase 6 change:** Before closing, add a mandatory step:

```
Phase 6 Step N: Promotion gate

1. Read review-learnings.md
2. For each AD-N and UG-N entry, compute occurrence count and severity
3. Present a table to the user:

   | Tag | Pattern | Occurrences | Severity | Recommendation |
   |-----|---------|-------------|----------|----------------|
   | AD-1 | ... | 3 | critical | promote |
   | AD-4 | ... | 2 | important | defer |

4. Recommendation rules:
   - Occurrences >= PROMOTION_THRESHOLD (default 3) → recommend promote
   - Severity in SEVERITY_OVERRIDE_PROMOTION (default ["critical"]) → recommend promote regardless of count
   - Else → recommend defer

5. User must explicitly decide for each entry: promote | defer (with written reason) | close
6. For promoted entries:
   - Append pattern to ${REVIEW_STANDARDS} under appropriate section
   - Move entry to "## Promoted to Review Standards" in review-learnings.md (audit trail, don't delete)
   - Tag with "promoted YYYY-MM-DD"
7. Do not close Phase 6 until every entry has a decision
```

**New plug points in project-config.yaml:**

```yaml
PROMOTION_THRESHOLD: 3                          # minimum occurrences for auto-recommend
SEVERITY_OVERRIDE_PROMOTION: ["critical"]       # severities that recommend promote at 1 occurrence
```

**Nuances:**
- **Severity at promotion time, not capture time.** An AD captured as "important" may graduate to "critical" after 10 occurrences. Let user re-classify.
- **Never auto-promote.** The gate *surfaces* decisions; it doesn't make them silently. Too easy to bloat review-standards.md with false positives.
- **Single-task bulk findings.** The CODE_REVIEW_CONSOLIDATED problem (20 hits in 1 task) is addressed by the severity override — critical-severity AD entries promote at 1 occurrence. Document this clearly.
- **Don't truncate occurrence history.** Keep full list of task IDs in the entry, not just a count. Useful for spotting whether a pattern is regressing after promotion.

**Acceptance:**
- [ ] Phase 6 includes a mandatory promotion gate step
- [ ] Table of AD/UG entries with counts and recommendations is surfaced to user
- [ ] User decision is required per entry (no silent auto-close)
- [ ] Promoted entries move to audit-trail section; never deleted
- [ ] PROMOTION_THRESHOLD and SEVERITY_OVERRIDE_PROMOTION are configurable

---

### FR-7: Shared-settings guidance

**Why:** fin-analyst's code-quality hooks (ruff format/check, py_compile) are in `settings.local.json` — per-user, uncommitted. They don't travel with the repo. Teammates and CI don't get them. This is a common mis-placement for P&E consumers.

**Design:**

**`setup-prompt.md` change:** During first-run auto-detection, after identifying the test/lint commands, ask:

> *"Install code-quality hooks (ruff/prettier/etc.) in shared settings.json so they travel with the repo? [Y/n]"*

If yes, and the project has an existing `settings.local.json` with PostToolUse hooks for Edit/Write on code files, offer to move them.

**`HELP.md` addition:** Document the distinction:

```markdown
## settings.json vs settings.local.json

- `.claude/settings.json` — committed, shared. Quality hooks (format/lint/type-check) that should apply to every developer belong here.
- `.claude/settings.local.json` — per-user, uncommitted (in .gitignore). Per-user permission overrides and experimental hooks belong here.
```

**Project-specific layer:** The actual hook commands (ruff for Python, prettier/eslint for JS, etc.) are stack-specific. P&E's auto-detection picks the right ones.

**Acceptance:**
- [ ] Setup prompt offers to install quality hooks in shared settings.json
- [ ] Offers to migrate existing PostToolUse hooks from settings.local.json
- [ ] HELP.md explains the distinction

---

## 3. Plug-point catalog (after these changes)

Add to `project-config-example.yaml`:

```yaml
plan-and-execute:
  # --- Existing ---
  PROJECT_ROOT: "."
  # MODULE_NAME: "auth"
  TEST_CMD: "uv run pytest"
  LINT_CMD: "uv run ruff check ."
  SECURITY_CMD: "uv run bandit -r . -ll"
  INTEGRATION_MARKERS: "-m integration"
  REVIEW_STANDARDS: "docs/review-standards.md"
  ENV_CONFIG_POLICY: "docs/env-config-policy.md"
  DOMAIN_REVIEWER: "domain-reviewer"
  PLAN_DIR: "docs/plans"
  SCAN_MODE: "docs"
  CONCEPT_MODE: "ask"
  DOC_TASK_MODE: "auto"

  # --- New from this spec ---
  REVIEW_PREAMBLE: ".claude/shared/review-preamble.md"   # FR-3
  PLAN_ANALYSER: "general-purpose"                        # FR-2
  PROMOTION_THRESHOLD: 3                                  # FR-6
  SEVERITY_OVERRIDE_PROMOTION: ["critical"]               # FR-6
  STATE_FILE: ".plan-and-execute.state.json"              # FR-1
```

The general rule for future plug points: **if a behavior varies by stack, domain, team preference, or risk tolerance, make it a project-config key. If it's a process-discipline rule derived from a real incident, bake it into SKILL.md or a scaffolded CLAUDE.md section.**

---

## 4. Non-goals (explicitly NOT in scope)

These were discussed during analysis and rejected:

- **Full `.harness/runs/<id>/` JSON state directory** (MediMigration-style). FR-1's single state file is the minimal structured state needed; the rest is MediMigration-specific complexity.
- **`defects.jsonl` + `policies.json` registry.** fin-analyst's markdown `review-learnings.md` mechanism (with FR-5 and FR-6 improvements) is sufficient. Don't invent parallel machine-readable defect registry.
- **Migration-specific skills** (`mg-*` from MediMigration — move-group migration, SQL generation, Playwright UI review). Project-specific, not portable.
- **Credential-scan hook inside P&E.** Already solved externally by the `secrets-guard` marketplace skill or a git pre-commit + gitleaks. Document this in HELP.md; don't reinvent.
- **Wiring-auditor / mutation-site-auditor / failure-path-auditor skills.** These are generalizable MediMigration validators, but they solve different problems than what the current consumers need. Evaluate separately if a consumer requests them. Not in the minimal patch.

---

## 5. Project-specific layer (NOT implemented here; consumer projects add after these land)

When a project adopts updated P&E, it adds its own layer. For fin-analyst specifically, after these FR-1 through FR-7 changes land and `install.sh` is re-run:

1. **`.claude/shared/review-preamble.md` content** — seed from existing `review-learnings.md` AD-1…AD-7 + escape classes from `docs/CODE_REVIEW_CONSOLIDATED.md`. Approximately:
   - Hardcoded credentials as config defaults
   - Domain-layer imports of non-stdlib (SQLAlchemy/Pydantic in `main/domain/`)
   - Async methods with blocking sync I/O body
   - Inline-arithmetic tests that don't exercise production code
   - Version/content hashes that include mutable identity fields
   - Provenance path divergence
   - Incomplete warning serialization
2. **Credential-scan enforcement** — install the `secrets-guard` skill and configure gitleaks for Python/pydantic patterns. NOT a P&E concern.
3. **Move ruff/py_compile hooks** from `fin-analyst/.claude/settings.local.json` to `settings.json` via the `setup-prompt.md` migration flow (FR-7).
4. **Backfill RCA fields** on AD-1…AD-7 per FR-5 migration note.
5. **Configure project-config.yaml** — set `PROMOTION_THRESHOLD`, `SEVERITY_OVERRIDE_PROMOTION`, and pick a `PLAN_ANALYSER` agent name.
6. **Worktree implications.** fin-analyst uses git worktrees (the user mentioned this). The state file lives in each worktree separately, which is correct — each worktree represents an independent feature run. Document this nuance in HELP.md.

MediMigration is already beyond these improvements (has its own `.harness/` infrastructure). It can continue to run its own harness layer on top of P&E without disruption.

---

## 6. Migration strategy for existing consumers

Two consumer projects use master P&E today: `fin-analyst` (local copy, Apr 2026) and `MediMigration` (local copy, earlier). Rolling these changes out:

1. **Land changes on master in this order:**
   - FR-1 (state file + hook) — no consumer impact unless install.sh is re-run
   - FR-5 (RCA fields) — additive, existing AD-N entries work fine
   - FR-6 (promotion gate) — additive, requires reading review-learnings.md
   - FR-3 (review-preamble) — requires setup re-run
   - FR-2 (Phase 3 dispatch) — SKILL.md behavior change
   - FR-4 (CLAUDE.md scaffolding) — requires setup re-run
   - FR-7 (shared-settings guidance) — requires setup re-run
2. **Diff fin-analyst's P&E against master before merging.** The Apr 18 2026 copy may have already evolved some of this. Reconcile.
3. **For MediMigration, the FR-1 state file may conflict** with its existing `.harness/runs/<id>/run.json`. Either:
   - Keep MediMigration on its harness layer and skip FR-1 adoption there, OR
   - Unify by having P&E optionally delegate state to `harness_cli.py` when configured
   Recommend the first option — don't bend the generic framework to accommodate MediMigration's specific needs.
4. **fin-analyst migration is clean.** No conflicting state infra.

---

## 7. Open questions for implementer

- Should the state file be per-feature (one file per concurrent run) or singleton (one file per working dir)? Current spec is singleton; flag if consumer needs parallelism.
- Should the Stop hook also block on `status="failed"` (force explicit recovery) or only on `status="in_progress"`? Current spec is only in_progress; "failed" is the user's escape hatch.
- Should the Phase 3 analyser dispatch preserve any context (e.g., findings.md contents) or truly run cold? Current spec: plan path only. May need to revisit if analysers hallucinate without codebase context.
- Is `PROMOTION_THRESHOLD=3` the right default? MediMigration uses this; happy to adjust.
- How should Phase 6 promotion gate interact with the CrossAI debate workflow (some projects use it)? Probably unaffected, but verify with a CrossAI-enabled test consumer.

---

## 8. Summary — what the implementer actually needs to build

| # | Deliverable | Files touched | Est. LOC |
|---|---|---|---|
| FR-1 | Stop hook + state file writes | `hooks/phase_guard.sh` (new), `SKILL.md` (~10 one-liners), `install.sh` (~15 lines) | ~80 |
| FR-2 | Fresh-subagent critic | `templates/plan-analyser-prompt.md` (new), `SKILL.md` Phase 3 (~40 lines) | ~120 |
| FR-3 | Review preamble + injection | `templates/review-preamble-template.md` (new), 3 reviewer prompt files, `SKILL.md` Phase 5, `setup-prompt.md` | ~150 |
| FR-4 | Agent Dispatch Discipline scaffolding | `templates/claude-md-agent-dispatch-discipline.md` (new), `setup-prompt.md` | ~100 |
| FR-5 | RCA fields in review-learnings | `templates/review-learnings-template.md` (edit), `SKILL.md` Phase 5 | ~30 |
| FR-6 | Phase 6 promotion gate | `SKILL.md` Phase 6 (~60 lines), `project-config-example.yaml` | ~80 |
| FR-7 | Shared-settings guidance | `setup-prompt.md` (~20 lines), `HELP.md` | ~40 |
| — | Plug-point catalog updates | `project-config-example.yaml`, `HELP.md` | ~20 |

Total: ~620 lines across ~15 files. All additive or scaffolded — no breaking changes to the orchestrator's existing phases.

When done, run the skill's own test harness (`scripts/` directory) against a fresh consumer project and against fin-analyst's existing state to verify both forward and backward compatibility.

---

## 9. Cleanup opportunities surfaced during the analysis

A redundancy pass over the consumer projects and the master P&E repo surfaced several cleanup items. They are out of scope for the core FR-1…FR-7 work (nothing here changes P&E semantics) but should be addressed alongside so the end state is coherent.

### 9.1 Master P&E repo cleanup

| Item | What | Why | Effort |
|---|---|---|---|
| 9.1a | Add a one-line cross-reference header to both `agent-spec-reviewer-prompt.md` and `spec-reviewer-prompt.md` | Files differ by ~10 lines and are easy to mistake for duplicates. Current cross-reference is buried at line 5. Promote to line 1. | 2 lines total |
| 9.1b | Add "Three review-R content contract" section to `HELP.md` | Lock in the boundary between `review-standards.md` / `review-learnings.md` / `review-preamble.md` (new) before content drift starts. Reference this section from FR-3, FR-5, FR-6. | ~30 lines |
| 9.1c | Add "Domain code review: skill vs agent invocation surfaces" to `HELP.md` | Clarify that `domain-code-review/SKILL.md` is the user-invokable slash-command form; the scaffolded `domain-reviewer.md` agent is how P&E dispatches internally during Phase 5/6. Different surfaces, same rules. | ~15 lines |
| 9.1d | Add "Known overlapping plugins" subsection to `HELP.md` | Explicitly document: (i) do NOT combine with `superpowers:writing-plans` / `executing-plans` (FR-2 nuance); (ii) `superpowers:receiving-code-review` is complementary not overlapping (FR-3 nuance); (iii) `superpowers:verification-before-completion` is complementary — prompt-side discipline reinforcing FR-1 harness-side enforcement; (iv) `claude-md-management:claude-md-improver` must respect FR-4 sentinel markers; (v) use `secrets-guard` instead of shipping credential-scan inside P&E (already in §4 Non-goals). | ~40 lines |

All four items belong in HELP.md so consumers find them when setting up or auditing their installation. Keep each subsection short with links into the relevant FR.

### 9.2 fin-analyst consumer cleanup (applies once FR-1…FR-7 land in master and fin-analyst re-runs install.sh)

These are NOT tasks for the implementing agent working in master P&E. They are captured here so the consumer project has a cleanup playbook ready.

| Item | What | Why | When |
|---|---|---|---|
| 9.2a | **Delete** `fin-analyst/.claude/agents/finanalyst-reviewer.md` (and update the root `StockMarket/.claude/agents/finanalyst-reviewer.md` symlink) | 95% identical to `domain-reviewer.md` — diff shows only a name field, path-templating, and a paragraph describing the 14 sections of review-standards.md. `domain-reviewer.md` is the P&E-scaffolded templated version; `finanalyst-reviewer.md` is the hand-authored hardcoded duplicate. Keep one. | After FR-3 lands (the review-preamble pattern makes the right canonical agent form explicit) |
| 9.2b | **Archive** `fin-analyst/.claude/Skills_Workflow-claude.md` (643 lines, dated 2026-02-23) and `fin-analyst/.claude/automation-recommendations.md` (285 lines, dated 2026-02-14) to `docs/archive/` | Both predate the current plan-and-execute SKILL.md and have historical-only value. Keeping them in `.claude/` invites drift — another agent may follow the old narrative instead of the current SKILL.md. | Any time; independent of FR work |
| 9.2c | **Trim** the "Phase Gate Enforcement (plan-and-execute)" section in `fin-analyst/.claude/CLAUDE.md` to a single pointer line: *"Phase gates are enforced mechanically by `.claude/hooks/phase_guard.sh`; see `.plan-and-execute.state.json` for current phase. Never bypass."* | Once FR-1 is in place, the hook enforces what the CLAUDE.md rule asks for in prose. CrossAI flagged prose ≠ enforcement; keeping the full rule AND the hook means two statements of the same thing can drift. Keep the pointer so the discoverable rule is not lost, but remove the duplicate prose. | After FR-1 lands |
| 9.2d | **Move** the 7 AD-1…AD-7 entries' content into the fin-analyst scaffolded `shared/review-preamble.md` "Project-specific escape classes" section | FR-3 preamble explicitly has a project-specific section; fin-analyst should populate it from its existing review-learnings.md. Keep AD entries in review-learnings.md too (the session ledger); the preamble section is a digest for reviewers. | After FR-3 lands |

### 9.3 MediMigration consumer (no cleanup required)

MediMigration runs its own `.harness/` layer on top of P&E and is beyond these improvements. FR-1's state file would collide with MediMigration's existing `run.json`, so MediMigration should NOT adopt FR-1's state file directly — its `harness_phase_guard.sh` already does the same job against its own state. Document this in HELP.md (FR-7 alongside the shared-settings guidance).

---

## 10. Verification checklist for the implementing agent

Before declaring this work done, verify against both consumer projects:

- [ ] Run `install.sh` in a scratch directory. Confirm all new templates scaffold correctly.
- [ ] Run `install.sh` against `fin-analyst` (on a branch). Confirm FR-1 state file machinery coexists with existing `.crossai` Stop hook (does not clobber it).
- [ ] Confirm FR-3's `REVIEW_PREAMBLE` falls back gracefully when the file is missing (delete it after scaffolding; verify reviewers still run and log a warning).
- [ ] Confirm FR-2's critic dispatch works when `PLAN_ANALYSER="none"` (falls back to inline analysis).
- [ ] Confirm FR-4's sentinel markers allow a second install.sh run to update the bounded block without duplicating content.
- [ ] Confirm FR-5's new fields don't break existing consumers whose `review-learnings.md` has legacy AD entries without those fields (backward-compatibility check).
- [ ] Confirm FR-6's Phase 6 gate surfaces all AD/UG entries and REQUIRES explicit per-entry decisions (no silent auto-close).
- [ ] Confirm FR-7's setup prompt migrates `settings.local.json` PostToolUse hooks to `settings.json` when user says yes (and doesn't clobber if user says no).
- [ ] Run an end-to-end P&E feature cycle on a toy project: Phase 0 scaffolds everything, Phases 2–5 write state, Phase 6 surfaces promotion gate, Stop hook blocks premature exit in mid-Phase-5.
- [ ] Confirm no breaking changes to the orchestrator's existing phases: a consumer who does not re-run install.sh after this update must continue to work as before (FR-1 hook exits 0 silently when state file doesn't exist; reviewer dispatch works without preamble; etc.).
