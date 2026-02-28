# Code Review Standards

> Copy this file to `${REVIEW_STANDARDS}` (default: `docs/review-standards.md`) and customize for your project.
> This file is tool-agnostic -- referenced by Claude Code subagents, review skills, and CI checks.
> Sections marked <!-- CUSTOMIZE --> need project-specific content.

---

# 0. REVIEW PROCESS & WORKFLOW

## Review Mode

- Prioritize correctness and invariant safety over style.
- Review changed files first; include pre-existing debt only if the diff introduces or worsens it.
- Report only high-confidence findings (80%+ certainty of a real problem).
- Keep style-only comments minimal unless they impact readability, reliability, or maintainability.
- When a plan/spec/tasks artifact exists, evaluate completion against plan must-haves, not only diff quality.

## Workflow

1. **Identify planned scope**: If a plan/spec/tasks artifact exists, extract must-have deliverables and acceptance criteria.

2. **Identify scope**: List changed files and map each to its layer:

   <!-- CUSTOMIZE: Replace with your project's layer mapping -->
   | Layer | Path pattern | Primary review focus |
   |---|---|---|
   | core | `src/core/*` | Data models, type contracts, business logic |
   | services | `src/services/*` | Service layer, orchestration, external integrations |
   | api | `src/api/*` | REST/GraphQL endpoints, request validation, response format |
   | config | `src/config/*` | Settings, feature flags, environment vars |
   | tests | `tests/*` | Test quality, coverage, no hardcoded values |

3. **Load relevant sections**: Use the layer mapping to prioritize which sections below to apply. All invariants (section 5) always apply regardless of layer.

4. **Validate behavior before commenting on style**: Check correctness, invariants, and contracts first. Style issues come second.

5. **Plan coverage mapping**: Map implemented code and tests to each must-have plan item; classify as Implemented, Partial, Missing, or Deferred (with trigger).

6. **For each finding**, provide: severity, file+line, what is wrong, why it matters, which rule/invariant is violated, fix direction.

## Severity Rubric

| Severity | Meaning | Blocks merge? |
|---|---|---|
| **Critical** | Correctness or data integrity failure | Yes |
| **High** | Strong regression risk or invariant violation | Yes, until fixed |
| **Medium** | Important quality gap, should be fixed soon | No, but track |
| **Low** | Non-blocking improvement | No |

- Missing a plan must-have deliverable is at least **High** severity unless explicitly approved as deferred with a clear trigger.

## Guardrails

- Do not claim invariants that are not actually implemented in this codebase.
- Do not recommend broad refactors unless the diff requires them.
- Do not flag style-only issues unless they impact reliability or maintainability.
- If unsure whether something is an issue, note it as an observation under "Residual Risk & Testing Gaps", not as a finding.
- Keep standards module-agnostic: prefer reusable rules over component-specific guidance unless a rule is truly domain-wide.

---

# 1. ARCHITECTURE & MODULE BOUNDARIES

<!-- CUSTOMIZE: Document your project's module structure -->
## Module Structure

```
src/
  core/        # Central data models and business logic
  services/    # Service layer and external integrations
  api/         # API endpoints
  config/      # Settings and feature flags
tests/         # Test suite
```

## Boundary Rules -- Flag Violations

<!-- CUSTOMIZE: Define your project's architectural boundaries -->
1. **Layer separation**: Each layer communicates only through defined interfaces. No direct cross-layer imports bypassing the service layer.
2. **Config centralization**: Runtime configuration lives in a single config module. No scattered hardcoded values.
3. **Model integrity**: Canonical data models are defined in one place. Other modules should not redefine these structures.

---

# 2. DOMAIN-SPECIFIC RULES

<!-- CUSTOMIZE: Add domain-specific correctness rules for your project -->
<!-- Examples:
- For financial apps: scoring logic, data source precedence, calculation accuracy
- For mapping apps: confidence scores, vector search, LLM prompt correctness
- For e-commerce: pricing rules, inventory constraints, payment flow
-->

(Add your domain-specific review rules here)

---

# 3. CLEAN CODE RULES -- ENFORCE STRICTLY

## Logging

### Statement Rules
- **REQUIRED**: Use lazy `%` formatting: `logger.info("Processing item: %s", item_name)`
- **VIOLATION**: f-strings in logging: `logger.info(f"Processing item: {item_name}")`
- **VIOLATION**: `print()` statements in production code

### Infrastructure Rules
- **REQUIRED**: New modules must use `logger = logging.getLogger(__name__)`
- **VIOLATION**: Module-level `logging.basicConfig()` — use the project's centralized logging config
- **VIOLATION**: Custom `logging.FileHandler` / `StreamHandler` setup in application modules — logging infrastructure belongs in the project's `logging_config.py`
- **REQUIRED**: If project has a `logging:` section in `project-config.yaml`, all logging must conform to its configured destination, format, and level

## Exception Handling

- **REQUIRED**: Handle specific exceptions, not bare `except Exception`
- **REQUIRED**: Re-raise with chaining: `raise ValueError("msg") from e`
- **VIOLATION**: Swallowing exceptions silently: `except Exception: return None`

## Imports

- **REQUIRED**: stdlib -> third-party -> local ordering (PEP 8)
- **VIOLATION**: Inline imports (inside functions) unless there is a documented circular dependency reason

## YAGNI and Simplicity

- No over-engineering: no abstract protocols for single implementations, no factories for simple construction
- No backwards-compatibility shims (renaming unused `_vars`, re-exporting removed types)
- No dead code: unused imports, commented-out code blocks, unreachable branches
- No magic numbers: thresholds, weights, multipliers should be named constants or come from configuration
- Prefer flat code over deeply nested conditionals

## Naming

- Variables/functions: `snake_case`
- Classes: `PascalCase`
- Constants: `UPPER_SNAKE_CASE`

---

# 4. TEST QUALITY CRITERIA

## Test Conventions (Enforce These)

<!-- CUSTOMIZE: Adjust test style and markers for your project -->
1. **Style**: BDD with Given-When-Then in docstrings
2. **Integration-first**: Prefer integration tests for end-to-end workflows
3. **No hardcoded pass values**: Tests validate structure, ranges, and relationships
4. **Test naming**: `test_given_<condition>_when_<action>_then_<expected_result>`
5. **Environment-aware**: Tests requiring external APIs should be marked appropriately (e.g., `@pytest.mark.integration`)

## Test Anti-Patterns -- Flag These

1. **Overlapping tests**: two tests asserting the same invariant on the same data path
2. **Testing implementation details**: accessing protected attributes couples tests to internals
3. **Hardcoding values to pass**: `assert score == 0.85` is brittle
4. **No new test files without justification**: add tests to existing files first

---

# 5. INVARIANTS -- FLAG ANY VIOLATION

These are non-negotiable system invariants.

<!-- CUSTOMIZE: Define your project's invariants -->

## Data Invariants

1. (Define data integrity rules for your domain)
2. (Define required fields, valid ranges, consistency rules)

## API Invariants

3. All API endpoints return proper status codes and structured responses
4. Error responses include actionable error messages

## Configuration Invariants

5. API keys and secrets must come from environment variables, never hardcoded
6. Feature flags must have documented defaults

---

# 6. REVIEW OUTPUT FORMAT

Structure your review as follows:

## Findings (ordered by severity)

For each finding include:
- **Severity**: Critical / High / Medium / Low
- **File**: file path and line numbers
- **What is wrong**: concrete description
- **Why it matters**: impact on correctness, safety, or maintainability
- **Rule/Invariant violated**: reference to specific section and number above
- **Fix direction**: suggested approach

## Plan Traceability Matrix (required when plan/spec/tasks exist)

Include a table with:
- Plan item
- Priority (Must/Should)
- Evidence (file:line, test, command output)
- Status (Implemented/Partial/Missing/Deferred)
- Defer trigger (if Deferred)

## Residual Risk & Testing Gaps (optional)

Note any areas where the diff may have introduced risk that is not fully covered by existing tests.

## Checklist Summary

- [ ] Module boundaries respected
- [ ] Domain-specific rules followed
- [ ] Clean code rules followed (logging format, logging infrastructure, exception handling, imports)
- [ ] Test quality criteria met
- [ ] Plan must-have items are implemented or explicitly deferred with trigger
- [ ] No hardcoded secrets or credentials
- [ ] Configuration changes documented

---

**Confidence threshold**: Only report issues where you are 80%+ confident there is a real problem. If unsure, note it under "Residual Risk & Testing Gaps" as an observation, not as a finding.
