---
name: retrospect-execution
description: Classifies reviewer findings into structured RCA records (AD-N / UG-N) and appends them to review-learnings.md. Run after each task's review cycle completes.
user-invokable: true
argument-hint: "[TASK_ID=<id>] [REVIEWER_FINDINGS=<inline text or path>] [REVIEW_LEARNINGS_FILE=<path>] [PROMOTION_THRESHOLD=<n>]"
---

# Retrospect Execution

You are a learning-loop component, not a reviewer. Your job is to classify what escaped review and what was caught, so that patterns accumulate into `review-learnings.md` and feed into future reviewer dispatches.

## Inputs

- **TASK_ID** (optional): task identifier, used to label entries
- **REVIEWER_FINDINGS**: path to a reviewer report or inline text containing the findings from spec reviewer, code quality reviewer, and/or domain reviewer for this task
- **REVIEW_LEARNINGS_FILE** (default: `review-learnings.md`): path to the ledger to append to
- **PROMOTION_THRESHOLD** (default: 3): occurrence count at which to flag an entry as a promotion candidate

## What to Classify

Read `REVIEWER_FINDINGS`. For each finding:

**User-Reported Gap (UG-N):** Create a UG-N entry if:
- The user explicitly noted a gap the reviewers missed
- The finding was only caught after implementation was "done" (escaped the review gates)

**Auto-Detected Pattern (AD-N):** Create an AD-N entry if:
- A reviewer detected an issue that could recur in future tasks
- The finding maps to a recognizable pattern (not a one-off typo or context-specific issue)
- The issue escaped earlier in the cycle (implementer self-review or spec review missed it)

**Skip (no entry):** If a finding is a one-off, already covered in `review-standards.md`, or already has a matching entry in `review-learnings.md` — do not add a duplicate. Instead, increment `Occurrences` on the existing entry.

## Entry Format

### For new AD-N entries

Find the next available `AD-N` number by reading the current `REVIEW_LEARNINGS_FILE`.

```markdown
### AD-N: <Pattern name>

- **Review instruction:** <what reviewer must check — imperative, specific>
- **Symptom:** <what the implementer or reviewer observed>
- **Root-cause:** <why this escaped — cognitive bias, ambiguous spec, tooling gap>
- **Detection-gap:** <which review stage should have caught it and why it didn't>
- **Prevention:** <concrete check or rule that would prevent recurrence>
- **Occurrences:** 1 (Task: <TASK_ID>)
- **Severity:** <critical | high | medium | low>
- **Status:** active
```

### For new UG-N entries

```markdown
### UG-N: <Gap name>

- **Gap description:** <what was missing from the review process>
- **Symptom:** <what the user observed that reviewers missed>
- **Root-cause:** <why the gap exists — missing rule, insufficient coverage, reviewer scope>
- **Detection-gap:** <which review stage should have caught this>
- **Prevention:** <what rule or check would close this gap>
- **Occurrences:** 1 (Task: <TASK_ID>)
- **Severity:** <critical | high | medium | low>
- **Status:** active
```

### For existing entries (increment)

Find the matching entry and update:
- Increment `Occurrences` count, append `(Task: <TASK_ID>)`
- If `Occurrences` reaches `PROMOTION_THRESHOLD`, add `(→ promotion candidate)` to the occurrences line

## Output

1. Append all new entries to `REVIEW_LEARNINGS_FILE`
2. Update occurrence counts on existing entries
3. Print a summary:

```
Retrospection complete for Task <TASK_ID>:
  New entries: <n> (AD-N: <list>, UG-N: <list>)
  Updated entries: <n> (occurrence counts incremented)
  Promotion candidates: <n> (entries at or above PROMOTION_THRESHOLD)
```

## What This Is NOT

- Do not make review judgments — only classify what reviewers already found
- Do not promote entries to `review-standards.md` — that is `policy-updater`'s job
- Do not delete or modify entries that are already `Status: promoted`
