---
name: domain-code-review
description: Run a project-specific code review against review-standards.md, env-config-policy.md, and logging policy. Works standalone or as a delegate from plan-and-execute.
user-invokable: true
argument-hint: "[BASE_SHA..HEAD_SHA | files to review]"
---

# Domain Code Review

Project-specific code review that enforces your review standards, domain rules, invariants, logging policy, and env-config policy. Complements generic code-quality reviewers (like `superpowers:code-reviewer`) by adding the project-specific layer.

**When to use standalone:** After implementing a feature, before merging, or anytime you want a standards-aware review without running the full plan-and-execute lifecycle.

**When used by plan-and-execute:** Invoked automatically during Phase 5 (per-task domain review) and Phase 6 (final domain review).

## Scope Resolution

Determine what to review based on invocation:

1. **Explicit SHA range:** `/domain-code-review abc123..def456` — review diff between those commits
2. **Explicit files:** `/domain-code-review src/auth.py src/models.py` — review those files
3. **No arguments:** review current working tree changes (`git diff` + `git diff --cached`)

```bash
# Resolve scope
if [[ "$ARGS" =~ \.\. ]]; then
  # SHA range: git diff BASE..HEAD
  SCOPE="commit-range"
elif [[ -n "$ARGS" ]]; then
  # Explicit file list
  SCOPE="files"
else
  # Working tree
  SCOPE="working-tree"
fi
```

## Configuration Resolution

Read project config to find review artifacts. Use the same resolution order as plan-and-execute:

1. Check for `project-config.yaml` in `.claude/` or project root
2. Apply defaults for anything not configured

| Config key | Default | Purpose |
|------------|---------|---------|
| REVIEW_STANDARDS | `docs/review-standards.md` | Project review rules |
| ENV_CONFIG_POLICY | `docs/env-config-policy.md` | Env/config policy |
| logging (block) | (none) | Logging compliance policy |

If `REVIEW_STANDARDS` does not exist, warn the user and offer to bootstrap from template:
> "No review-standards.md found at `docs/review-standards.md`. Run `install.sh` to bootstrap project templates, or create one manually from `templates/review-standards-template.md`."

## Review Execution

Dispatch a subagent to perform the review:

```
Task tool (subagent_type: feature-dev:code-reviewer):
  description: "Domain code review"
  prompt: |
    You are reviewing code changes against project-specific standards.

    ## Scope
    [Resolved scope — SHA range, file list, or working tree diff]

    ## Step 1: Load Project Standards

    Read these files before reviewing any code:
    - ${REVIEW_STANDARDS} — the canonical review standards for this project
    - ${ENV_CONFIG_POLICY} — environment and configuration policy (if exists)

    ## Step 2: Identify Changed Files

    [For commit range]: git diff --stat BASE..HEAD
    [For files]: the provided file list
    [For working tree]: git diff --stat + git diff --cached --stat

    Map each changed file to its layer using the layer table in review-standards.md (Section 1).

    ## Step 3: Review Against Standards

    Apply ALL applicable sections from review-standards.md:

    **Section 1 — Architecture & Module Boundaries:**
    - Check boundary rules, layer separation, config centralization

    **Section 2 — Domain-Specific Rules:**
    - Apply project-specific correctness rules

    **Section 3 — Clean Code Rules:**
    - Logging: statement rules (lazy % formatting, no print) AND infrastructure rules (getLogger, no basicConfig, no custom handlers)
    - Exception handling, imports, YAGNI, naming
    [If logging: block exists in project-config.yaml]:
    - Verify logging conforms to configured destination/format/level

    **Section 4 — Test Quality Criteria:**
    - BDD style, integration-first, no hardcoded values, naming, anti-patterns

    **Section 5 — Invariants:**
    - Check ALL declared invariants (data, API, configuration)

    **Config sprawl** (from env-config-policy.md):
    - No committed secrets, module-local config, typed defaults, documented keys

    ## Step 4: Output

    Use the output format from review-standards.md Section 6:

    ### Findings (ordered by severity: Critical > High > Medium > Low)
    Per finding: severity, file:line, what is wrong, why it matters, rule/invariant violated, fix direction.

    ### Plan Traceability Matrix (if plan/spec/tasks artifacts exist)
    Plan item | Priority | Evidence | Status | Defer trigger

    ### Residual Risk & Testing Gaps
    Areas where changes may have introduced risk not covered by existing tests.

    ### Checklist Summary
    - [ ] Module boundaries respected
    - [ ] Domain-specific rules followed
    - [ ] Clean code rules followed (logging format, logging infrastructure, exception handling, imports)
    - [ ] Test quality criteria met
    - [ ] No hardcoded secrets or credentials
    - [ ] Configuration changes documented

    **Confidence threshold**: Only report findings at 80%+ confidence.
    If unsure, note under Residual Risk, not as a finding.
```

## Severity Rubric

Use the rubric from review-standards.md:

| Severity | Meaning | Blocks merge? |
|----------|---------|---------------|
| **Critical** | Correctness or data integrity failure | Yes |
| **High** | Strong regression risk or invariant violation | Yes, until fixed |
| **Medium** | Important quality gap, should be fixed soon | No, but track |
| **Low** | Non-blocking improvement | No |

## Integration with plan-and-execute

When invoked by plan-and-execute:
- **Phase 5:** Called per-task after spec-compliance and generic code-quality reviews pass. Receives SHA range from the task's commits.
- **Phase 6:** Called once on the full branch diff for final domain review. Replaces the raw `${DOMAIN_REVIEWER}` agent dispatch.

plan-and-execute passes additional context:
- Task requirements (from the plan)
- `review-learnings.md` (accumulated review patterns from the session)

When invoked standalone, these are not available — the review focuses purely on standards compliance.

## Relationship to Other Reviewers

This skill is **one layer** in a multi-layer review stack:

| Layer | Skill/Agent | What it checks | When |
|-------|-------------|----------------|------|
| Spec compliance | `spec-reviewer-prompt.md` | Did they build what was requested? | plan-and-execute Phase 5 only |
| Generic quality | `superpowers:code-reviewer` | SOLID, DRY, security (confidence-scored) | Anytime |
| **Domain standards** | **`domain-code-review` (this skill)** | **Project-specific rules, invariants, logging, config** | **Anytime (standalone or via plan-and-execute)** |

