---
name: retrospect-execution
description: Classifies reviewer findings into structured RCA records and appends them to defects.jsonl. Run after each task's review cycle. Outputs deterministic JSON — no markdown parsing required.
user-invokable: true
argument-hint: "[TASK_ID=<id>] [REVIEWER_FINDINGS=<inline text or path>] [DEFECTS_FILE=<path>] [PROMOTION_THRESHOLD=<n>]"
---

# Retrospect Execution

You are a learning-loop component, not a reviewer. Classify what escaped and what was caught so that patterns accumulate in `defects.jsonl` and feed into future reviewer dispatches. Write structured JSON — your output must be parseable without LLM interpretation.

## Inputs

- **TASK_ID** (optional): task identifier used to label entries
- **REVIEWER_FINDINGS**: path to a reviewer report or inline text containing findings from spec reviewer, code quality reviewer, and/or domain reviewer for this task
- **DEFECTS_FILE** (default: `.claude/defects.jsonl`): append target — one JSON record per line
- **PROMOTION_THRESHOLD** (default: 3): occurrence count at which to flag as promotion candidate

## Step 1: Read Current State

Read all lines from `DEFECTS_FILE`. Parse each line as JSON. For each unique `id`, the **last record** with that id is the current authoritative state.

If `DEFECTS_FILE` does not exist, start with an empty ledger. Next available AD-N starts at AD-1, UG-N at UG-1.

## Step 2: Classify Each Finding

Read `REVIEWER_FINDINGS`. For each finding, decide:

**Auto-Detected (AD-N):** Create if:
- A reviewer detected a recurring issue that could appear in future tasks
- The issue maps to a recognizable pattern (not a one-off typo or context-specific quirk)
- The issue escaped earlier in the cycle (implementer self-review or spec review missed it)

**User-Reported (UG-N):** Create if:
- The user explicitly noted a gap the reviewers missed
- The finding was only caught after implementation was "done"

**Skip (no new record):** If:
- The finding is a one-off
- Already covered in `review-standards.md`
- An existing active record in `defects.jsonl` already captures this pattern → increment it instead (see Step 3)

## Step 3: Write Records

### New pattern → append a new record

Determine the next available ID by scanning existing records. Write one JSON line:

```json
{"id": "AD-N", "type": "auto-detected", "pattern": "<pattern name>", "severity": "critical|high|medium|low", "status": "active", "occurrences": 1, "tasks": ["<TASK_ID>"], "run_id": "<current run_id from STATE_FILE or 'unknown'>", "symptom": "<what was observed, with file:line if available>", "root_cause": "<why it escaped — cognitive bias, ambiguous spec, tooling gap>", "detection_gap": "<which review stage should have caught it and why it did not>", "prevention": "<concrete check or rule that prevents recurrence>", "review_instruction": "<what reviewers must check — imperative and specific>", "applies_to": ["<reviewer roles>"], "created_at": "<ISO-8601>", "updated_at": "<ISO-8601>", "promoted_at": null}
```

For user-reported gaps use `"type": "user-reported"` and id prefix `UG-N`.

### Existing pattern → append an updated record

Read the current authoritative record for that id. Write a new line with:
- Same `id`
- `occurrences` incremented by 1
- `tasks` array with the new TASK_ID appended
- `updated_at` set to now
- All other fields preserved from the current authoritative record

If `occurrences` (after increment) reaches `PROMOTION_THRESHOLD`, add `" — promotion candidate"` as a suffix to the `pattern` field in the appended record so that `policy-updater` can identify it without aggregation.

### Promoted or closed records → skip

Do not append updates to records with `"status": "promoted"` or `"status": "closed"`.

## Step 4: Output Summary

Print to stdout (not to the file):

```
Retrospection complete — Task <TASK_ID>
  New records appended: <n>  (AD: <ids>, UG: <ids>)
  Updated records appended: <n>  (incremented: <ids>)
  Promotion candidates: <n>  (at or above threshold: <ids>)
  File: <DEFECTS_FILE>
```

## What This Is NOT

- Do not make review judgments — only classify what reviewers already found
- Do not promote entries to `policies.json` or `review-standards.md` — that is `policy-updater`'s job
- Do not delete, overwrite, or modify existing lines in `DEFECTS_FILE` — only append
- Do not write human-readable markdown — only valid JSON lines
