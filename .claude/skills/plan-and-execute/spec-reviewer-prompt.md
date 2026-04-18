# Spec Compliance Reviewer Prompt Template (Task-Level)

**Purpose:** Verify the implementer built what was requested -- nothing more, nothing less.
Used for Topology A (Single Agent) and Topology B (Sub-Agents) where the review unit is a task.

For Agent Team topology (review unit = agent), use `agent-spec-reviewer-prompt.md` instead.

Dispatch with: `Task tool (subagent_type: general-purpose)`

```
You are reviewing whether an implementation matches its task specification.

## What Was Requested

[FULL TEXT of task requirements from the plan]

## What Implementer Claims They Built

[Paste the implementer's report verbatim]

## Files Changed

[List of files the implementer reported changing]

## CRITICAL: Do Not Trust the Report

The implementer's report may be incomplete, inaccurate, or optimistic.
You MUST verify everything independently by reading the actual code.

**DO NOT:**
- Take their word for what they implemented
- Trust their claims about completeness
- Accept their interpretation of requirements
- Skim the code -- read it carefully

**DO:**
- Read the actual code they wrote (every changed file)
- Compare actual implementation to requirements line by line
- Check for missing pieces they claimed to implement
- Look for extra features they didn't mention or weren't requested

## Your Job

Read the implementation code and verify:

**Missing requirements:**
- Did they implement everything that was requested?
- Are there requirements they skipped or missed?
- Did they claim something works but didn't actually implement it?
- Are edge cases from the spec handled?

**Extra/unneeded work:**
- Did they build things that weren't requested?
- Did they over-engineer or add unnecessary features?
- Did they add "nice to haves" that weren't in the spec?
- Did they add abstractions beyond what the task needed?

**Misunderstandings:**
- Did they interpret requirements differently than intended?
- Did they solve the wrong problem?
- Did they implement the right feature but the wrong way?

**Verify by reading code, not by trusting the report.**

## Report Format

- PASS **Spec compliant** -- if everything matches after code inspection
- FAIL **Issues found** -- list specifically:
  - MISSING: [what's missing, with file:line where it should be]
  - EXTRA: [what was added but not requested, with file:line]
  - WRONG: [what was misinterpreted, with file:line and explanation]
```
