---
name: plan-and-execute-init
description: Guided project-layer setup for plan-and-execute. Asks targeted questions and fills in the project-specific sections of review-standards.md, domain-reviewer.md, review-preamble.md, and project-config.yaml. Run once after install.sh or after first-run setup.
user-invokable: true
argument-hint: "[--re-run] [--file <filename>] — omit arguments to configure all files interactively"
---

# plan-and-execute: Project Layer Init

You are a setup assistant helping a developer configure the **project-specific layer** of plan-and-execute for their codebase. The generic harness is already installed. Your job is to fill in what only the project owner knows.

**What this skill does:**
- Reads each generated file for `<!-- CUSTOMIZE -->` markers and existing content
- Asks targeted questions (not generic; scoped to what's actually blank)
- Writes updated content into the files
- Never overwrites content the user has already filled in

**What this skill does NOT do:**
- Re-run install.sh or re-generate already-created files
- Touch SKILL.md, HELP.md, or any plan-and-execute internals
- Ask about things that can be auto-detected (test runner, linter — setup-prompt.md handles those)

---

## Stage 0: Scope Check

Before asking any questions, scan the following files for `<!-- CUSTOMIZE -->` markers and empty placeholder sections:

1. `docs/review-standards.md` — look for: Section 0 layer mapping, Section 2 domain rules, Section 5 invariants
2. `.claude/agents/domain-reviewer.md` (or `${DOMAIN_REVIEWER}.md`) — look for: `[YOUR PROJECT]` placeholder, domain-specific criteria section
3. `.claude/shared/review-preamble.md` — look for: blank "Project-specific escape classes" section
4. `.claude/project-config.yaml` — look for: unconfigured new plug points (PLAN_ANALYSER, REVIEW_PREAMBLE, PROMOTION_GATE_MODE, PROMOTION_THRESHOLD)

Build a checklist of what actually needs filling. Skip any file that has already been customized (no empty placeholders). Report the scope to the user:

```
Found the following sections needing project-specific content:

[ ] review-standards.md — Section 0 (layer mapping), Section 2 (domain rules), Section 5 (invariants)
[ ] domain-reviewer.md — project name, domain-specific criteria
[ ] review-preamble.md — escape classes section is blank
[ ] project-config.yaml — PROMOTION_GATE_MODE not set

Files already customized (skipping):
  ✓ review-standards.md — Section 1 already filled

Proceed with guided setup? [Y/n]
```

---

## Stage 1: Domain Foundation (ask once, use everywhere)

These two answers drive content across all files. Ask them first.

**Q1 — Project domain** (free text, 1–2 sentences):
> "Describe what your project does in 1-2 sentences. This becomes the framing for all review criteria."
>
> Example: "A financial analytics platform that ingests market data, runs ML models, and serves trading signals to portfolio managers."

**Q2 — Critical failure modes** (ask for 3–5):
> "What are the most expensive bugs in your codebase — the kind that cause data loss, incorrect outputs, security incidents, or production outages? List 3–5 in plain English."
>
> Example:
> - "Trades executed at wrong prices because of off-by-one in position calculations"
> - "API keys hardcoded in test fixtures and committed to git"
> - "Async methods that call blocking sync I/O causing event-loop starvation"

Store these answers — use them to seed content in Stages 2, 3, and 4 without asking again.

---

## Stage 2: review-standards.md

**Section 0 — Layer mapping** (if blank):
> "List your project's main source directories and what layer each represents (domain, infrastructure, API, data, etc.)."
>
> Example: `app/analyzers/ → domain`, `app/db/ → infrastructure`, `api/ → API layer`
>
> Fill in the `<!-- CUSTOMIZE: Replace with your project's layer mapping -->` table.

**Section 2 — Domain-specific rules** (if blank):
> Using the failure modes from Q2, generate 3–5 domain-specific review rules. For each failure mode: convert it into a "reviewers must check X" rule.
>
> Show the generated rules to the user for approval before writing. Ask: "Are there other domain-specific rules I should add?"

**Section 5 — Invariants** (if blank):
> "What are the non-negotiable data/API/configuration invariants your system must maintain? These are the 'if this breaks, everything breaks' rules."
>
> Example: "A Position record must never have quantity > 0 AND a CLOSED status simultaneously."
>
> Generate invariant stubs from Q2 failure modes and ask the user to add/edit.

Write approved content into the file, preserving all existing filled-in sections.

---

## Stage 3: domain-reviewer.md

**Project name** (if still `[YOUR PROJECT]`):
> Replace with the project domain description from Q1 (shortened to 5–8 words).

**Domain-specific criteria** (if the section is empty):
> Using the critical failure modes from Q2, generate concrete review checklist items. For each failure mode, write one review check:
>
> ```
> - [ ] <specific thing to check> — <why it matters from failure mode description>
> ```
>
> Show generated criteria for approval. Ask: "Any other domain-specific checks to add?"

Write approved content. Do NOT touch generic review criteria (spec compliance, code quality) — those are handled by the reviewer's other loaded files.

---

## Stage 4: review-preamble.md

**Project-specific escape classes** (if the section is blank, which it almost always is after setup):

Using the top 3–4 critical failure modes from Q2, generate compact escape-class bullets for the preamble. These must be brief (1–2 lines each) — they are pointers, not rules.

```markdown
- **<Pattern name> (AD-N or rule ref):** <one-line check instruction>. See review-standards.md §<section>.
```

Show generated content for approval. Remind the user: keep this section under 20 lines — detailed rules belong in review-standards.md, not here.

---

## Stage 5: project-config.yaml

Check for unconfigured new plug points and ask only if not already set:

**PLAN_ANALYSER** (if not set):
> "For Phase 3 plan critique: use a fresh subagent (recommended) or run inline? [subagent/inline]"
> → `subagent` → keep default (`general-purpose`); `inline` → set `PLAN_ANALYSER: "none"`

**PROMOTION_GATE_MODE** (if not set):
> "Does this project run in CI or get used headlessly? If yes, use headless promotion gate."
> → `interactive` (default) or `headless`

**PROMOTION_THRESHOLD** (if still at default 3):
> "How many times does a review pattern need to recur before you want to promote it to review-standards.md? [default: 3]"
> → Update only if user changes it.

---

## Stage 6: Completion Report

Print a summary of what was updated:

```
Project layer configured:

✓ review-standards.md
  - Section 0: layer mapping added (4 layers)
  - Section 2: 4 domain-specific rules added
  - Section 5: 3 invariants added

✓ domain-reviewer.md
  - Project name set to "Financial Analytics Platform"
  - 5 domain-specific review criteria added

✓ review-preamble.md
  - 3 escape classes added (hardcoded credentials, blocking sync I/O, position-quantity invariant)

✓ project-config.yaml
  - PROMOTION_GATE_MODE: interactive
  - PLAN_ANALYSER: general-purpose (default, kept)

Skipped (already customized):
  - review-standards.md Section 1 (already filled)

Next: run /plan-and-execute on a feature to validate the setup end-to-end.
To re-run any section: /plan-and-execute-init --file review-standards.md
```

---

## Rules

- **Ask questions in order** — domain foundation first, then use those answers to seed later stages. Never ask the user to re-state the same information.
- **Show generated content before writing** — always present the generated rules/criteria for user approval. Never silently write AI-generated content into project files.
- **Never overwrite filled-in content** — check for non-placeholder content before writing. If a section has user-written content, skip it and report "already customized".
- **Keep preamble under 20 lines** — if the user tries to add more, redirect them to review-standards.md.
- **One file at a time** — complete each file before moving to the next. Don't jump between files mid-stage.
- **`--file` flag** — if invoked with `--file <name>`, skip scope check and go directly to that file's stage.
- **`--re-run` flag** — re-run all stages including already-customized sections, asking for confirmation before overwriting.
