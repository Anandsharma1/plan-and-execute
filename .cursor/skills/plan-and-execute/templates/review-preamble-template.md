# Review Agent Preamble

Every review subagent dispatched by plan-and-execute MUST begin by reading this file.
Hard cap: keep this file under 80 lines. It is a pointer-and-posture file, NOT a rules catalog.
The authoritative rules live in the files listed under "Mandatory reads" below.

## Mandatory reads before reviewing

1. `${REVIEW_STANDARDS}` — project-specific review rules; authoritative escape-class catalog
2. `${ENV_CONFIG_POLICY}` — env/config boundary rules (if it exists)
3. Each file listed in `${REVIEW_CONTEXT_MAP}` — optional project-specific docs (architecture, invariants, glossary) the reviewer must weigh. Skip this step if the list is empty or unset.
4. The review-context-compiler digest injected above this prompt (accumulated defect patterns from `defects.jsonl`, role-filtered and severity-sorted)

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
     Keep the visible list under 20 lines. Link to review-standards.md for the full catalog.

     Example entry format:
     - **Hardcoded credentials (AD-1):** Check all default values, env fallbacks, and test fixtures
       for embedded API keys, passwords, or tokens. See review-standards.md §2.

     Generic starter set (uncomment to activate; replace with project-specific patterns as defects accumulate — these are illustrative defaults, not prescriptive rules):

     - **Stub/fake data on production paths** — hardcoded scores, placeholder names, zero-value results that pass type checks but silently mislead users
     - **Missing-metric null-collapse** — `value or 0`, `sum(x or 0 for …)`, `int(x or 0)` over a metric that may legitimately be None
     - **Data-precedence overwrite** — enricher writing over a non-empty authoritative value; enrichment must be additive (fill missing only)
     - **Thin-adapter violation** — business logic inside a router / controller beyond schema validation and error mapping
     - **Cross-boundary internal import** — inner module reaching across a declared seam
     - **Mutating immutable state** — write to an existing lineage / version record / content-addressed artifact post-creation
     - **State-machine backward transition** — skipping or reversing a declared forward-only transition
     - **Unjustified abstraction** — new protocol / factory / wrapper without a current boundary and ≥2 real implementations
     - **Error-handling anti-patterns** — bare `except:`; broad `except Exception` without a narrow documented reason; `from X import Y` inside `except:` or `finally:` (late ImportError shadows the original exception)
-->

## Output

Produce the full output structure defined in `${REVIEW_STANDARDS}` §6 (REVIEW OUTPUT FORMAT) — Findings, Plan Traceability Matrix (when plan/spec/tasks exist), Residual Risk & Testing Gaps, Checklist Summary.

Operating rules:

- Tag findings **Critical / High / Medium / Low** (rubric in `${REVIEW_STANDARDS}` §Severity)
- Emit an **Approved / Changes-required** verdict
- Critical and High findings block commit unless the user explicitly defers
- Apply an 80%+ confidence threshold — uncertainty goes under Residual Risk, not as a finding
- Map findings to plan must-haves when a plan file was provided

---

> **Dispatcher-side framing** ("verify these claims, not confirm these changes"; no
> completion-report injection; adversarial prompt construction) is the orchestrator's
> responsibility — see `CLAUDE.md` → Agent Dispatch Discipline → Review prompt design.
> Do not restate those rules here.
