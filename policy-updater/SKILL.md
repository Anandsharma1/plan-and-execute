---
name: policy-updater
description: Promotion gate — presents qualified review-learnings entries for promotion to review-standards.md. Supports interactive (blocks for user decision) and headless (emits bundle) modes.
user-invokable: true
argument-hint: "[GATE_MODE=interactive|headless] [REVIEW_LEARNINGS_FILE=<path>] [REVIEW_STANDARDS_FILE=<path>] [PROMOTION_THRESHOLD=<n>] [SEVERITY_OVERRIDE_PROMOTION=<levels>]"
---

# Policy Updater

You are a governance component. Your job is to identify patterns in `review-learnings.md` that have crossed the promotion threshold and either get user decisions on each (interactive) or emit a structured bundle for later review (headless).

## Inputs

- **GATE_MODE** (default: `interactive`): `interactive` | `headless`
- **REVIEW_LEARNINGS_FILE** (default: `review-learnings.md`): the session ledger
- **REVIEW_STANDARDS_FILE** (default: `docs/review-standards.md`): the durable rule library
- **PROMOTION_THRESHOLD** (default: 3): minimum occurrences for a promote recommendation
- **SEVERITY_OVERRIDE_PROMOTION** (default: `["critical"]`): severities that recommend promotion at 1 occurrence

## Step 1: Identify Qualified Entries

Read `REVIEW_LEARNINGS_FILE`. Build the promotion table:

For each AD-N and UG-N entry with `Status: active`:
- **Recommend promote** if: `Occurrences >= PROMOTION_THRESHOLD` OR severity is in `SEVERITY_OVERRIDE_PROMOTION`
- **Recommend keep** if: below threshold and not severity-override
- **Skip** if: `Status: promoted` (already done)

## Step 2a: Interactive Mode

Present the table:

```
Promotion Gate — Review Learnings

| Entry | Pattern | Severity | Occurrences | Recommendation |
|-------|---------|----------|-------------|----------------|
| AD-1  | <name>  | high     | 4           | PROMOTE        |
| AD-3  | <name>  | critical | 1           | PROMOTE (critical override) |
| UG-1  | <name>  | medium   | 2           | KEEP (below threshold) |

For each PROMOTE entry, decide: [P]romote / [K]eep / [D]efer
For each KEEP entry, decide: [K]eep / [P]romote anyway
```

Wait for user decision on each entry. Do NOT auto-decide.

**On PROMOTE decision:**

1. Find or create the appropriate section in `REVIEW_STANDARDS_FILE` (Section 2 for domain rules, Section 5 for invariants, or a "Recurring Patterns" section)
2. Add a clean, implementer-facing rule (not the RCA text — distill it into an actionable check):

```markdown
### <Pattern name>

**Rule:** <imperative statement — what must always / never be done>
**Check:** <specific thing a reviewer verifies>
**Why:** <one sentence — derived from Root-cause in the ledger entry>
```

3. Update the entry in `REVIEW_LEARNINGS_FILE`: set `Status: promoted`, add `Promoted: <date>`

**On KEEP / DEFER decision:** No changes to either file. Log the decision.

## Step 2b: Headless Mode

Do NOT block for user input. Instead:

1. Write `promotion-bundle.md` in the project root:

```markdown
# Promotion Bundle — <run_id> — <date>

Requires policy decision. The following entries crossed the promotion threshold during this run.

## Promote Recommendations

| Entry | Pattern | Severity | Occurrences | Rationale |
|-------|---------|----------|-------------|-----------|
| ...   |         |          |             |           |

## Keep Recommendations

| Entry | Pattern | Severity | Occurrences | Rationale |
|-------|---------|----------|-------------|-----------|
| ...   |         |          |             |           |

To act on these: run `/policy-updater GATE_MODE=interactive` or edit review-standards.md manually.
```

2. Do NOT write to `REVIEW_STANDARDS_FILE`
3. Do NOT update `Status` in `REVIEW_LEARNINGS_FILE`
4. Signal to orchestrator: set STATE_FILE `status: "needs-policy-decision"`

## Step 3: Summary

```
Policy Updater complete:
  Promoted: <n> entries → review-standards.md
  Kept: <n> entries (below threshold, user decision)
  Deferred: <n> entries
  [Headless: bundle written to promotion-bundle.md — <n> entries pending decision]
```

## What This Is NOT

- Do not evaluate whether entries are correct — only apply the threshold rules and user decisions
- Do not edit `review-standards.md` without user approval (interactive) or explicit instruction
- Do not run retrospection — that is `retrospect-execution`'s job
