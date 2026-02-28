# Environment and Configuration Policy

> Copy this file to `${PROJECT_ROOT}/docs/env-config-policy.md` and customize for your project.
> Referenced by the plan-and-execute skill during Phase 5 (code quality review) and Phase 6 (config sprawl check).

## Purpose
Define one shared policy for environment and configuration concerns across all AI coding agents and reviewers.

## Scope
Applies to all changes touching:
- `.env` or environment variables
- config files and config models
- runtime paths, users, hosts, ports, credentials, API keys, DSNs

## Rules

### 1. Do not commit secrets
- Never commit real API keys, passwords, tokens, DSNs, or credential files.
- Use placeholders in examples and docs.

### 2. Do not hardcode secrets in source code
- Secrets must come from environment variables or approved secret stores.

### 3. Module-local configuration
- Prefer module-scoped config over global root config.
- Keep module-specific `.env` under the module directory unless there is a documented shared need.
<!-- Customize: If your project uses a single root .env, adjust this rule accordingly. -->

### 4. Typed config and explicit defaults
- New config keys must have typed definitions and documented defaults.
- Production-sensitive values (credentials, hosts, ports, users, paths) must not rely on hidden implicit defaults.
<!-- Customize: Specify your config framework (pydantic-settings, python-dotenv, dynaconf, etc.) -->

### 5. Document every new config key
- Update the relevant module `README.md` (or config docs) with:
  - variable name
  - type
  - default behavior
  - required/optional
  - example value (non-secret)

### 6. Port and path changes require impact notes
- When changing ports, filesystem paths, or user-facing runtime endpoints, document compatibility and migration impact.

### 7. Environment safety in tests
- Tests requiring external credentials/network must detect missing prerequisites and skip with clear reasons.
- Deterministic component tests should not require live credentials.

## Review Checklist
- No committed secrets or credential leakage.
- No hardcoded credentials in code.
- Config follows module-local policy.
- New keys are typed and documented.
- PATH/port/user/host changes include impact notes.
