# Review Agent Preamble

Every review subagent dispatched by plan-and-execute MUST begin by reading this file.
Hard cap: keep this file under 80 lines. It is a pointer-and-posture file, NOT a rules catalog.
The authoritative rules live in the files listed under "Mandatory reads" below.

## Mandatory reads before reviewing

1. `${REVIEW_STANDARDS}` — project-specific review rules; authoritative escape-class catalog
2. `${ENV_CONFIG_POLICY}` — env/config boundary rules (if it exists)
3. The review-context-compiler digest injected above this prompt (accumulated defect patterns from `defects.jsonl`, role-filtered and severity-sorted)

## Derive status from code, not prose

- Do NOT trust "Done" claims in the implementer's report
- Read the diff: `git diff <base>...HEAD`
- Verify every required behavior is reachable from a non-test runtime path
- Verify every "Must NOT" constraint is satisfied

## Adversarial enumeration

For every new public function / endpoint / flow, verify behavior for:

- empty collections and None inputs
- missing artifacts (files, DB rows, config keys)
- already-completed or idempotent-operation entities
- concurrent mutations (optimistic vs. pessimistic locking assumptions)
- partial failures (first step succeeds, second fails — is state left consistent?)

Silent success on a no-op is a **Critical** finding.

## Project-specific escape classes

<!-- Project seeds this section from defects.jsonl AD-N entries (run /retrospect-execution to generate them).
     Keep to <20 lines. Link to review-standards.md for the full catalog.
     Example entry:
     - **Hardcoded credentials (AD-1):** Check all default values, env fallbacks, and test fixtures
       for embedded API keys, passwords, or tokens. See review-standards.md §2.
-->

## Output

Every review must produce:
- **Critical / Important / Minor** severity tags per finding
- **Approved / Changes-required** verdict
- Critical and Important findings block commit (unless user explicitly defers Important)
- Map findings to plan must-haves (if a plan file was provided)

---

> **Dispatcher-side framing** ("verify these claims, not confirm these changes"; no
> completion-report injection; adversarial prompt construction) is the orchestrator's
> responsibility — see `CLAUDE.md` → Agent Dispatch Discipline → Review prompt design.
> Do not restate those rules here.
