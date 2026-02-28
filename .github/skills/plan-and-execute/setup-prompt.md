# plan-and-execute — Project Setup

This file is loaded by Phase 0 when `.claude/.plan-and-execute-setup.done` does not exist. It guides one-time project configuration.

Auto-detect project configuration from the codebase, ask 2-3 questions, and generate all required config and review files.

**Rules:**
- Never overwrite existing files. If a target file exists, skip it and report "SKIP (exists)".
- All detection is best-effort. If detection fails, use the skill default and note it in the summary.
- Keep questions to 3 maximum. Do not ask about anything that can be auto-detected.

---

## Stage A: Auto-Detection

Scan the project root silently (no user interaction) and build a detection report:

| Signal | Detection method | What it fills |
|--------|-----------------|---------------|
| **Package manager** | `uv.lock` → uv; `poetry.lock` → poetry; `Pipfile` → pipenv; `requirements.txt` → pip | Command prefixes for `TEST_CMD`, `LINT_CMD`, `SECURITY_CMD` |
| **Test runner** | `pytest.ini`, `pyproject.toml` `[tool.pytest.ini_options]`, `setup.cfg` `[tool:pytest]` → pytest; `manage.py` → django test | `TEST_CMD` value |
| **Linter** | `ruff.toml`, `pyproject.toml` `[tool.ruff]` → ruff; `.flake8` → flake8; `.pylintrc` → pylint | `LINT_CMD` value |
| **Security scanner** | `bandit` in pyproject.toml deps or `.bandit` → bandit; `semgrep` in deps → semgrep | `SECURITY_CMD` value |
| **Project structure** | Scan top-level directories, identify layer patterns (`src/core/`, `app/models/`, `tests/`, `api/`, etc.) | Layer mapping table in `review-standards.md` section 0 |
| **Config framework** | `pydantic-settings`, `python-dotenv`, `dynaconf` in dependencies | Rule 4 note in `env-config-policy.md` |
| **Env patterns** | `.env`, `.env.example` files; check if module-local or root-level | Rule 3 adjustment in `env-config-policy.md` |

**Detection priority for linters:** ruff > flake8 > pylint (if multiple found, use the first match).

**Detection priority for package managers:** uv > poetry > pipenv > pip (if multiple lock files found, use the first match).

Present a brief detection summary to the user before proceeding:
```
Detected:
  Package manager: uv (found uv.lock)
  Test runner:     pytest (found pyproject.toml [tool.pytest])
  Linter:          ruff (found ruff.toml)
  Security:        bandit (found in pyproject.toml dependencies)
  Structure:       app/analyzers/, app/models/, tests/
  Config:          pydantic-settings
  Env:             root .env.example
```

---

## Stage B: Interactive Questions (3 max)

Ask only what cannot be auto-detected:

**Q1 — Domain name** (free text):
> "What is your project's domain? (e.g., 'financial analytics', 'e-commerce API', 'data pipeline')"

Used in: `domain-reviewer.md` header, `review-standards.md` section 2 heading.

**Q2 — Domain reviewer** (yes/no):
> "Create a domain-specific reviewer agent? You'll customize its review criteria later."

If yes: set `DOMAIN_REVIEWER` in config and generate `.claude/agents/<project-name>-reviewer.md` from template with the domain name filled in.
If no: leave `DOMAIN_REVIEWER` unset, skip domain reviewer file generation.

**Q3 — Logging preset** (only if no `logging:` block already exists in config):
> "Logging policy — choose a preset:"
>   1. `backend` — file, structured JSON, size rotation 10MB, 5 backups, INFO
>   2. `cli-tool` — terminal only, human-readable, INFO
>   3. `skip` — no logging enforcement

If `backend` or `cli-tool`: write the logging block to config and generate `logging_config.py` from `./templates/logging_config_template.py`.
If `skip`: omit logging block entirely. Phase 0 will note no logging policy.

---

## Stage C: File Generation

Generate the following files using templates from `./templates/`. Never overwrite existing files.

| File | Source template | What gets filled in |
|------|----------------|-------------------|
| `.claude/project-config.yaml` | `./templates/project-config-example.yaml` | Auto-detected commands (uncommented), logging block if preset chosen |
| `docs/review-standards.md` | `./templates/review-standards-template.md` | Layer mapping table from structure detection, domain name in section 2 heading |
| `docs/env-config-policy.md` | `./templates/env-config-policy-template.md` | Config framework name in rule 4, .env pattern note in rule 3 |
| `.claude/agents/<name>-reviewer.md` | `./templates/domain-reviewer-template.md` | Domain name in header and description (only if Q2 = yes) |
| `review-learnings.md` | `./review-learnings-template.md` | Unchanged (boilerplate) |
| `logging_config.py` | `./templates/logging_config_template.py` | Preset values substituted (only if logging preset chosen) |

Sections that require domain expertise retain their `<!-- CUSTOMIZE -->` comments or are marked with `TODO:` so the user knows what still needs manual attention.

---

## Stage D: Summary & Marker

Print a completion table:

```
Setup complete. Generated files:

| File                              | Status  | Action needed                    |
|-----------------------------------|---------|----------------------------------|
| .claude/project-config.yaml       | Created | Review detected commands         |
| docs/review-standards.md          | Created | Customize sections 2 and 5       |
| docs/env-config-policy.md         | Created | Review rules 3-4 for your stack  |
| .claude/agents/X-reviewer.md      | Created | Add domain-specific review rules |
| review-learnings.md               | Created | No action needed                 |
| logging_config.py                 | Created | Import in your app entrypoint    |

Continuing with plan-and-execute Phase 0...
```

Files that were skipped (already existed) are listed as "SKIP (exists)" with no action needed.

**After generating files**, create the marker file `.claude/.plan-and-execute-setup.done` with contents:

```
setup_completed: YYYY-MM-DD HH:MM
detected_package_manager: <value>
detected_test_runner: <value>
detected_linter: <value>
detected_security_scanner: <value>
domain: <value from Q1>
```

This marker prevents setup from triggering again on subsequent invocations. To re-run setup, delete this file.
