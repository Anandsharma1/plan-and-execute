# Code Quality Reviewer Prompt Template

**Purpose:** Verify implementation is well-built -- clean, tested, maintainable.

**Only dispatch after spec compliance review passes.** No point reviewing code quality on something that doesn't meet the spec.

## For Topology A/B (task-level review)

Dispatch with git SHA range scoped to the single task's changes:

```
Task tool (subagent_type: general-purpose):
  description: "Code quality review for Task N"
  prompt: |
    Review the code changes between commits [BASE_SHA] and [HEAD_SHA].

    ## What Was Implemented
    [From implementer's report -- what they claim they built]

    ## Task Requirements
    [Brief summary of the task from the plan]

    ## Your Job

    Review ONLY the diff between the two commits. Check for:

    **Code Quality:**
    - SOLID principles (especially Single Responsibility, Open/Closed)
    - DRY -- no unnecessary duplication
    - YAGNI -- no over-engineering beyond what the task required
    - Clean, readable code with clear naming
    - Consistent with existing codebase patterns

    **Testing Quality (quality over quantity -- reject filler tests):**
    - Every test must answer: "what functional behavior does this prove works?"
    - Tests assert real outcomes (return values, state changes, observable side effects) -- not that mocks were called
    - A test that passes by construction (e.g., mocking the very thing being tested) is a CRITICAL issue -- flag it
    - Edge cases covered where the task spec mentions them
    - Tests are readable and maintainable
    - No test pollution (tests clean up after themselves)
    - Padding tests that exist only to inflate count -> flag as Important issue

    **Security (CWE -- flag as CRITICAL, do not defer):**
    - CWE-89: SQL injection (raw string queries, unparameterized DB calls)
    - CWE-78: OS command injection (shell=True, unvalidated subprocess args)
    - CWE-79: XSS (if any HTML output is generated)
    - CWE-798: Hardcoded credentials, API keys, or secrets in source files
    - CWE-327: Weak or broken cryptographic algorithm
    - CWE-502: Insecure deserialization (pickle, yaml.load without Loader=)
    - CWE-400: Resource exhaustion (unbounded loops, unclosed file handles)
    - General: input validation at system boundaries, no injection vulnerabilities

    **Logging compliance** (if ${REVIEW_STANDARDS} exists, enforce its logging rules):
    - Uses lazy `%` formatting, not f-strings in log calls
    - No `print()` in production code
    - New modules use `logger = logging.getLogger(__name__)`, not `logging.basicConfig()`
    - No custom handler setup in application modules — logging infrastructure belongs in the project's centralized config
    - If project has a `logging:` section in project-config.yaml, verify conformance to configured destination/format/level

    **Config sprawl** (if ${ENV_CONFIG_POLICY} exists, enforce its rules):
    - New config values use python-dotenv pattern (or project-appropriate config mechanism, not hardcoded defaults in logic)
    - No secrets or API keys in committed source files
    - Module-specific config in module directory, not root
    - New config keys have type hints and are documented in module README or docstring

    **Report Format:**
    - **Strengths:** What was done well
    - **Issues:** (Critical / Important / Minor) with file:line references
    - **Assessment:** Approved / Approved with minor issues / Changes required
```

## For Topology C (agent-level review)

Same prompt structure, but scope the diff to the agent's changed files:

```
    Review the code changes in these files: [agent's changed file list]
    between commits [PRE_AGENT_SHA] and [POST_AGENT_SHA].

    Context: This agent's role was [agent role from spec].
    It was responsible for: [summary of agent's scope from spec].
```

The rest of the prompt (checks, report format) is identical to the task-level version.
