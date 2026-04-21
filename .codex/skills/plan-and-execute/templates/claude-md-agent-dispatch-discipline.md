<!-- BEGIN plan-and-execute:agent-dispatch-discipline -->
## Agent Dispatch Discipline

### Parallel safety
- `isolation: "worktree"` does NOT reliably isolate file writes — parallel agents can still
  write to the main working directory. Observed incident: second agent ran `git stash` and
  wiped first agent's completed work.
- **Dispatch write-capable agents SEQUENTIALLY** — commit each agent's verified work before
  dispatching the next.
- **Read-only agents (reviewers, explorers, planners) CAN run in parallel.**

### Destructive git prohibition
Implementer subagent prompts MUST include verbatim:

> *"DO NOT run `git stash`, `git reset`, `git checkout`, `git clean`, `git restore`, or any
> destructive git command. Read-only git commands are fine."*

### Crash recovery
After a subagent crash or rate-limit, run `git status` and `git diff --stat` before
re-dispatching. If the diff is substantial and tests pass, the work is likely done — the cost
of verifying (5–10 tool calls) is much lower than re-dispatching from scratch (100+).

### Review prompt design
Review prompts MUST be adversarial:
- Frame as "verify these claims," not "review these changes"
- Do NOT include the implementer's completion report in the reviewer prompt
- Reviewer derives status from code, not prose
- Include a concrete adversarial checklist (3+ scenarios from the plan's edge-case section)

### Fix-back rounds
When a review finds a bug that escaped implementation, the fix-back round MUST produce a
structured RCA:
- **Symptom:** what went wrong observably
- **Root cause:** name the specific cognitive or process failure (not "be more careful")
- **Detection gap:** which review rule should have caught it
- **Prevention:** test / check / policy now guarding against regression

### Empirical verification
For bugs that depend on runtime semantics (async generators, DB transactions, state machines,
etc.), write a 20–30 line throwaway script that:
1. Reproduces the bug
2. Proves the fix works

Don't reason about runtime semantics — verify empirically.

### Mutation-test the guard
When you add a guard (test, invariant check, hook), mutate the invariant in place and verify
the guard FAILS. A passing test after adding a guard is not evidence the guard works — it
might be passing vacuously.

### Carry open issues forward
Every fix-back review prompt MUST include a "Still-open issues from prior rounds" section
listing previously identified unfixed issues by file and line. Diff-scope alone misses
defects in untouched files. If a known issue was not addressed in the current commit, the
reviewer must confirm it is still open.

### Sibling-pattern enforcement
When a fix is applied to function A (guard, null-check, resource close), the reviewer MUST
grep for all sibling functions with the same call pattern and verify each has the same fix.
A review that confirms function A is correct without checking B and C is incomplete.

### Write learnings back before the next round
After consolidating reviewer findings, new patterns MUST be written back to
`review-learnings.md` (or appended to `defects.jsonl` for the structured variant) BEFORE
dispatching the next review round. Patterns not written back are patterns the next reviewer
will miss.

### Parallel reviewers (recommended when available)
For medium+ complexity changes, dispatching a domain reviewer and a generic code-quality
reviewer in parallel is recommended — they are read-only and safe to parallelize, and each
surfaces different findings (domain rules vs. SOLID/security/style). Consolidate findings
before dispatching fix-back. This is guidance, not a hard rule: projects without a domain
reviewer, or with a lighter review surface, can safely skip it.
<!-- END plan-and-execute:agent-dispatch-discipline -->
