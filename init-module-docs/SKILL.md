---
name: init-module-docs
description: Scaffold docs/ directory for one or more app modules. Creates ARCHITECTURE.md, README.md, INVARIANTS.md, and tech-debt.md with content seeded from existing code. Skips files that already exist.
user-invokable: true
argument-hint: "<module-name> [<module-name2> ...]"
---

# init-module-docs

Scaffold the standard `docs/` directory for one or more `app/<module>` directories.
Creates four files per module, skipping any that already exist.

## Target Files

| File | Purpose |
|------|---------|
| `ARCHITECTURE.md` | Purpose, module boundaries, key components, data flow, design decisions |
| `README.md` | Usage, public API, setup, configuration, running tests |
| `INVARIANTS.md` | Domain invariants, data precedence rules, state machine constraints, cross-module contracts |
| `tech-debt.md` | Known debt items, severity, impact, workaround, resolution trigger |

## Execution

### Step 1 — Resolve modules

If the skill was invoked with arguments (e.g. `/init-module-docs market_data analyzers`), use those.

If no argument was provided, list available modules:
```bash
ls app/
```
Ask the user: "Which module(s) should I scaffold docs for? Available: [list]"
Accept a space-separated list. Process all of them.

### Step 2 — For each module, check what exists

```bash
ls app/<module>/docs/ 2>/dev/null
```

Build a list of files to create (skip any that already exist — never overwrite).
If all four files already exist, report "All docs present — nothing to do." and move on.

### Step 3 — Scan the module (quick, targeted)

Before writing any file, gather what you need from the code. Do this once per module:

1. Read `app/<module>/main/__init__.py` or `app/<module>/__init__.py` — public API surface
2. Glob `app/<module>/main/*.py` — list key files to understand the component structure
3. Read the `__init__.py` and 2–3 of the most central files (coordinator, service, repository, or the largest file) — enough to understand purpose, key classes, and data flow
4. Read any existing docs in `app/<module>/docs/` — reuse content, don't duplicate it
5. Check `app/<module>/test/` or `app/<module>/tests/` for test file names — confirms public behaviours

Apply the **2-Action Rule**: after every 2 reads, note your findings before continuing.
Do NOT do deep archaeology — 5–8 reads maximum. The goal is seeding, not full documentation.

### Step 4 — Create missing files

Create only the files identified as missing in Step 2. Use the templates below.
Fill in every section you can from the scan. Use `<!-- TODO: ... -->` for sections you cannot fill.

Write files to `app/<module>/docs/<FILE>`.

If `app/<module>/docs/` does not exist, create it first.

---

## File Templates

### ARCHITECTURE.md

```markdown
# <Module Name> — Architecture

> Last updated: <YYYY-MM-DD>

## Purpose

<1–3 sentences: what this module is responsible for. What problem does it solve?
What are its primary outputs? What does it explicitly NOT do?>

## Module Boundaries

```
<ASCII or simple text diagram showing this module and what it depends on / what depends on it.
Show cross-module relationships and the layer each sits in.>
```

Cross-module coupling: <describe how this module communicates with others — protocols,
direct imports, events, shared DB tables. Note any coupling that should be reduced.>

## Key Components

| Component | File(s) | Responsibility |
|-----------|---------|----------------|
| <class/service name> | `main/<file>.py` | <one-line responsibility> |
<!-- Add one row per significant class, service, or subsystem -->

## Data Flow

<Describe the primary request/response or event flow through the module.
What comes in? What transformations happen? What goes out? Where does data persist?>

## Design Decisions

| Decision | Rationale |
|----------|-----------|
<!-- Add rows as you discover decisions made in the code -->

## Known Constraints

<!-- Things that limit this module's design that future engineers should know -->
-
```

---

### README.md

```markdown
# <Module Name>

<One-sentence description of what this module does.>

## Public API

<!-- List the primary entry points (classes, functions, or FastAPI routes) a caller uses -->

```python
# <show the typical import and usage pattern>
```

| Class / Function | Description |
|-----------------|-------------|
<!-- One row per public symbol -->

## Setup

<!-- Prerequisites, environment variables, DB migrations, seed data -->

```bash
# <any setup commands>
```

**Configuration** (`.env` or environment variables):

| Variable | Default | Description |
|----------|---------|-------------|
<!-- One row per config key this module reads -->

## Usage

```python
# <minimal working example>
```

## Running Tests

```bash
# Component tests (no network/DB):
uv run --active pytest app/<module>/test/

# Integration tests (requires DB + network):
uv run --active pytest app/<module>/test/ -m integration
```

## Related Modules

| Module | Relationship |
|--------|-------------|
<!-- e.g. | `companies` | Provides symbol→ISIN resolution via Protocol | -->
```

---

### INVARIANTS.md

```markdown
# <Module Name> — Domain Invariants

> Invariants are non-negotiable rules this module must never violate.
> Any code change that breaks an invariant is a Critical defect.
> Last updated: <YYYY-MM-DD>

## Data Invariants

<!-- Rules about data shape, completeness, and correctness -->
- <!-- e.g. "All monetary values are stored in native currency units (INR), never normalised" -->

## State Machine Constraints

<!-- If the module has entities with lifecycle states, describe the valid transitions -->
- <!-- e.g. "A FetchAudit record moves only: pending → running → complete | failed" -->

## Boundary Conditions

<!-- How the module behaves at edges: empty inputs, missing data, holidays, zero values -->
- <!-- e.g. "An empty price series returns an empty list, never raises" -->

## Cross-Module Contracts

<!-- Protocols or interfaces this module depends on — what guarantees it expects -->
| Dependency | Contract |
|------------|---------|
<!-- e.g. | `SymbolResolver` (companies) | `resolve(ticker)` returns `str | None`, never raises | -->

## Precedence Rules

<!-- If multiple data sources exist, which takes priority and under what conditions -->
- <!-- e.g. "Screener data takes precedence over Yahoo when both provide the same field" -->
```

---

### tech-debt.md

```markdown
# <Module Name> — Tech Debt

> Track known shortcuts, workarounds, and deferred work here.
> Items are not bugs — they are intentional trade-offs that should be revisited.
> Last updated: <YYYY-MM-DD>

## Active Items

| Item | Severity | Impact | Workaround | Resolution Trigger |
|------|----------|--------|------------|-------------------|
<!-- Severity: High / Medium / Low -->
<!-- Impact: what breaks or degrades if this debt stays -->
<!-- Workaround: how callers currently cope -->
<!-- Resolution Trigger: what event or condition should prompt fixing this -->

## Resolved Items

| Item | Resolved | How |
|------|----------|-----|
<!-- Move items here once resolved, with date and brief description of the fix -->
```

---

## Output

After processing all modules, print a summary table:

| Module | File | Action |
|--------|------|--------|
| `<module>` | `ARCHITECTURE.md` | Created / Skipped (already exists) |
| `<module>` | `README.md` | Created / Skipped (already exists) |
| `<module>` | `INVARIANTS.md` | Created / Skipped (already exists) |
| `<module>` | `tech-debt.md` | Created / Skipped (already exists) |

If any TODOs were left in created files, list them:
> **TODOs remaining:** `app/<module>/docs/ARCHITECTURE.md` — Data Flow section needs filling in.

## Rules

- **Never overwrite** a file that already exists — report it as skipped.
- **Seed from code, not imagination** — only write content you found in the actual source. Use `<!-- TODO -->` for the rest.
- **Keep the scan short** — 5–8 reads maximum per module. This is scaffolding, not full documentation.
- **Write dates** — fill `<YYYY-MM-DD>` with today's date in every file.
- **Do not create review-standards.md** — that file is project-level at `docs/review-standards.md`.
