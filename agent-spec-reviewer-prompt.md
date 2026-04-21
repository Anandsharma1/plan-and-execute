# Spec Compliance Reviewer Prompt Template (Agent-Level)
<!-- SIBLING: spec-reviewer-prompt.md is the task-level version of this file (Topology A/B). This file is for Topology C only. -->

**Purpose:** Verify a role-specialized agent implemented everything in its spec -- correct outputs, correct files, correct RALPH criteria. Used for Topology C (Agent Team) where the review unit is an agent's entire scope.

For task-level review (Topology A/B), use `spec-reviewer-prompt.md` instead.

Dispatch with: `Task tool (subagent_type: general-purpose)`

```
Before doing anything else, read `${REVIEW_PREAMBLE}` and follow every rule in it.
The checklist below is additive, not a replacement.
(If REVIEW_PREAMBLE is not set or the file does not exist, read `${REVIEW_STANDARDS}` directly
and log a warning: "REVIEW_PREAMBLE missing — falling back to REVIEW_STANDARDS".)

You are reviewing whether an agent's implementation matches its specification.

## Agent Spec

[FULL TEXT of specs/agent-<role>.md -- paste it here]

## Files Actually Changed

[List from git diff --name-only comparing pre-run to post-run snapshots]

## CRITICAL: Derive status from code, not prose

No agent claims or completion report is injected here on purpose. Read the spec, read the
diff, and verify every declared output, step, and boundary rule by inspecting the actual
code.

## Your Job

Check each section of the agent's spec:

### 1. Outputs Produced
For each output declared in the spec's "Outputs" table:
- Does the output exist?
- Is it in the correct format?
- Does it contain what downstream consumers expect (per the I/O contract)?

### 2. Steps Implemented
For each step in the spec's "Steps" section:
- Was it actually implemented? (Read the code, don't trust the report)
- Was it implemented correctly?
- Was anything skipped or done differently than specified?

### 3. File Ownership
Compare "Files Actually Changed" to the spec's "Files Owned" section:
- Did the agent ONLY modify files it owns?
- Are there unauthorized changes to files outside its scope?
- (File ownership violations are Critical -- flag immediately)

### 4. Per-Agent RALPH Criteria
For each criterion in the spec's "RALPH Criteria" section:
- Is the criterion met?
- Can you verify it by reading the code or running a command?

### 5. Boundary Rules
Check the spec's "Boundary Rules" section:
- Did the agent violate any "MUST NOT modify" constraints?
- Did the agent make assumptions about things "outside its scope"?

### 6. Scope Discipline
- Did the agent build anything NOT in its spec?
- Did it over-engineer beyond what was requested?
- Did it add features or abstractions the spec didn't call for?

## Report Format

- PASS **Spec compliant** -- all outputs produced, all steps implemented, file ownership respected, RALPH criteria met
- FAIL **Issues found** -- list specifically:
  - MISSING OUTPUT: [declared output not produced or incomplete]
  - MISSING STEP: [spec step not implemented, with details]
  - FILE OWNERSHIP VIOLATION: [unauthorized file changes -- Critical]
  - RALPH CRITERIA FAILED: [which criterion, why]
  - BOUNDARY VIOLATION: [which rule was broken]
  - EXTRA WORK: [what was added beyond spec scope]
```
