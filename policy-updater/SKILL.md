---
name: policy-updater
description: Promotion gate — reads defects.jsonl, presents qualified entries for promotion, writes decisions to policies.json and review-standards.md. Supports interactive and headless modes.
user-invokable: true
argument-hint: "[GATE_MODE=interactive|headless] [DEFECTS_FILE=<path>] [POLICIES_FILE=<path>] [REVIEW_STANDARDS_FILE=<path>] [PROMOTION_THRESHOLD=<n>] [SEVERITY_OVERRIDE_PROMOTION=<levels>]"
---

# Policy Updater

You are a governance component. Read `defects.jsonl`, identify entries that have crossed the promotion threshold, and either get user decisions on each (interactive) or emit a structured bundle for later review (headless). All file I/O is JSON — no markdown parsing required for decision logic.

## Inputs

- **GATE_MODE** (default: `interactive`): `interactive` | `headless`
- **DEFECTS_FILE** (default: `.claude/defects.jsonl`): the session ledger
- **POLICIES_FILE** (default: `.claude/policies.json`): the active policy registry
- **REVIEW_STANDARDS_FILE** (default: `docs/review-standards.md`): human-facing rule library (receives promoted rules as readable text)
- **PROMOTION_THRESHOLD** (default: 3): minimum occurrences for a promote recommendation
- **SEVERITY_OVERRIDE_PROMOTION** (default: `["critical"]`): severities that recommend promotion at 1 occurrence
- **CONTEXT_DIR** (default: `.claude`): directory where `promotion-bundle.json` is written in headless mode
- **STATE_FILE** (optional): path to the phase guard state file — read to extract `run_id` for `promotion-bundle.json`. If absent, `run_id` is written as `"unknown"`.

## Step 1: Build the Defect State

Read all lines from `DEFECTS_FILE`. For each unique `id`, take the **last record** as authoritative (JSONL append-only semantics). Exclude records with `"status": "promoted"` or `"status": "closed"`.

Read `POLICIES_FILE` to get current policy IDs (for next P-N numbering).

## Step 2: Classify

For each active defect record, apply:
- **Recommend PROMOTE** if: `occurrences >= PROMOTION_THRESHOLD` OR `severity` is in `SEVERITY_OVERRIDE_PROMOTION`
- **Recommend KEEP** otherwise

Build two lists: `promote_recommendations` and `keep_recommendations`.

## Step 3a: Interactive Mode

Present the table to the user:

```
Promotion Gate

| ID   | Pattern                          | Severity | Occurrences | Recommendation         |
|------|----------------------------------|----------|-------------|------------------------|
| AD-1 | Missing input validation         | high     | 4           | PROMOTE (threshold)    |
| AD-3 | F-string in logger               | critical | 1           | PROMOTE (critical)     |
| UG-1 | Edge case not in spec            | medium   | 2           | KEEP (below threshold) |

For each entry, decide: [P]romote / [K]eep / [C]lose
```

Wait for user decision on each entry. Do NOT auto-decide.

**On PROMOTE decision:**

1. Read `POLICIES_FILE`. Determine next P-N id.

2. Append a new policy to `policies.json`:
   ```json
   {
     "id": "P-N",
     "source_defect_id": "<defect id>",
     "mode": "active",
     "rule": "<distilled imperative rule — not the RCA text>",
     "check": "<specific thing a reviewer verifies>",
     "why": "<one sentence — derived from root_cause in defect record>",
     "promoted_at": "<ISO-8601>"
   }
   ```
   Write the updated `policies.json` (full file rewrite — it is not append-only).

3. Append a clean rule to `REVIEW_STANDARDS_FILE` under the appropriate section. Format for humans:
   ```markdown
   ### <Pattern name> (P-N)

   **Rule:** <imperative statement>
   **Check:** <specific reviewer verification>
   **Why:** <one sentence rationale>
   ```

4. Append an updated record to `DEFECTS_FILE` with `"status": "promoted"`, `"promoted_at": "<ISO-8601>"`, all other fields preserved.

**On KEEP / CLOSE decision:** No file changes. Log the decision in the summary.

## Step 3b: Headless Mode

Do NOT block for user input. Do NOT write to `POLICIES_FILE` or `REVIEW_STANDARDS_FILE`.

Write `${CONTEXT_DIR}/promotion-bundle.json`:

```json
{
  "run_id": "<from STATE_FILE or 'unknown'>",
  "generated_at": "<ISO-8601>",
  "promote_recommendations": [
    {
      "defect_id": "<id>",
      "pattern": "<pattern>",
      "severity": "<severity>",
      "occurrences": <n>,
      "reason": "threshold|critical-override"
    }
  ],
  "keep_recommendations": [
    {
      "defect_id": "<id>",
      "pattern": "<pattern>",
      "severity": "<severity>",
      "occurrences": <n>,
      "reason": "below threshold"
    }
  ],
  "action": "Run /policy-updater GATE_MODE=interactive to resolve, or edit .claude/policies.json manually"
}
```

Signal to orchestrator: set STATE_FILE `status: "needs-policy-decision"`.

## Step 4: Summary

```
Policy Updater complete (GATE_MODE=<mode>):
  Promoted: <n> entries → policies.json + review-standards.md (IDs: <list>)
  Kept: <n> entries
  Closed: <n> entries
  [Headless: promotion-bundle.json written — <n> entries pending decision]
```

## What This Is NOT

- Do not evaluate whether defect records are correct — only apply threshold rules and user decisions
- Do not edit `review-standards.md` without explicit user approval (interactive) or instruction
- Do not run retrospection — that is `retrospect-execution`'s job
- Do not overwrite existing policies in `policies.json` — only append new entries
