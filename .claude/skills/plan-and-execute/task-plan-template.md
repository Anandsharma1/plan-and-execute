# Task Plan: [Brief Description from user input]

## Parameters
| Parameter | Value |
|-----------|-------|
| PROJECT_ROOT | [fill in] |
| MODULE_NAME | [fill in] |
| PLAN_DIR | docs/plans |
| REVIEW_STANDARDS | [fill in] |
| ENV_CONFIG_POLICY | [fill in] |
| DOMAIN_REVIEWER | [fill in or "none"] |
| TEST_CMD | [fill in] |
| LINT_CMD | [fill in] |
| SECURITY_CMD | [fill in] |
| DOC_TASK_MODE | [fill in] |

## Available Dependencies
| Dependency | Available? | Notes |
|---|---|---|
| planning-with-files | [yes/no] | |
| ralph-loop | [yes/no] | |
| superpowers | [yes/no] | |
| speckit | [yes/no] | |
| Domain reviewer | [yes/no/not configured] | Agent: [name or "none"] |

## Goal
[One sentence from user's request]

## Current Phase
Phase 1

## Phases

### Phase 0: Conflict Check + Initialize Context Files
- [x] Resolved parameters (config file + invocation overrides + defaults)
- [x] Checked for active ralph-loop or prior planning files
- [x] Created task_plan.md
- [x] Created findings.md
- [x] Created progress.md
- **Status:** complete

### Phase 1: Concept & Design
- [ ] Present concept/design options to user (or skip if CONCEPT_MODE=skip)
- [ ] Execute chosen path (brainstorming / speckit / both / skip)
- [ ] Log chosen path and outputs in progress.md
- **Chosen path:** (filled after user chooses)
- **Status:** in_progress

### Phase 2: Research & Discovery
- [ ] Explore codebase for relevant modules and patterns
- [ ] Identify blast radius and dependencies
- [ ] Capture findings in findings.md
- [ ] List open questions and assumptions
- **Status:** pending

### Phase 3: Plan Generation & Analysis
- [ ] Generate formal RALPH plan (inline methodology, consuming findings.md + Phase 1 artifacts)
- [ ] Run 7-dimension plan analysis (inline -- no external skill)
- [ ] Apply amendments or fix blockers (if any)
- [ ] Re-analyse after fixes (if needed, max 2 cycles)
- [ ] Present plan + analyser report to user
- [ ] Get user approval on the plan
- **Status:** pending

### Phase 4: Task Breakdown
- [ ] Choose path: speckit:tasks (if spec.md exists + speckit available) OR manual breakdown
- [ ] Generate atomic tasks with dependencies
- [ ] Append Tasks section to plan.md (same file user approved)
- [ ] For Topology B/C: group tasks by workstream, mark parallelization
- **Task path used:** (speckit / manual)
- **Status:** pending

### Phase 5: Execution
- [ ] Execute plan via topology-dependent model (SDD for A/B, dedicated agents for C)
- [ ] Two-stage review per execution unit (spec compliance -> code quality)
- [ ] Update progress.md after each major milestone
- [ ] RALPH finalization loop passes
- **Status:** pending

### Phase 6: Finalization
- [ ] RALPH finalization loop all-green
- [ ] Security check passed (or skipped if SECURITY_CMD not set)
- [ ] Config sprawl check passed (or skipped if ENV_CONFIG_POLICY not set)
- [ ] Domain review completed (or skipped if DOMAIN_REVIEWER not set)
- [ ] Documentation updated (doc-lint + doc-sync)
- [ ] Branch ready for merge/PR
- **Status:** pending

## Plan Details
| Field | Value |
|-------|-------|
| Concept path | (filled in Phase 1) |
| Design doc | (filled in Phase 1, if applicable) |
| Spec file | (filled in Phase 1 or Phase 3, if applicable) |
| Plan file | (filled in Phase 3) |
| Topology | (filled in Phase 3) |
| Analyser verdict | (filled in Phase 3) |

## Decisions Made
| Decision | Rationale |
|----------|-----------|

## Errors Encountered
| Error | Attempt | Resolution |
|-------|---------|------------|
