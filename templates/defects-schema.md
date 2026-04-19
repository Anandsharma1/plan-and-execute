# Artifact Schemas

Schemas for the machine-readable artifacts written and read by plan-and-execute skills.
These artifacts enable deterministic skill-to-skill communication without LLM text parsing.

---

## defects.jsonl

**Location:** `${DEFECTS_FILE}` (default: `.claude/defects.jsonl`)
**Format:** Append-only JSONL — one complete JSON object per line.
**Behavior:** New patterns append a new record. Recurrences append an updated record (same `id`, incremented `occurrences`, extended `tasks`). The latest record for a given `id` is authoritative. Never delete or overwrite lines.

```json
{
  "id": "AD-1",
  "type": "auto-detected",
  "pattern": "Missing input validation on public endpoints",
  "severity": "critical|high|medium|low",
  "status": "active|promoted|closed",
  "occurrences": 3,
  "tasks": ["T-2", "T-4", "T-7"],
  "run_id": "add-auth-20260419123456",
  "symptom": "No validation on user-supplied data before passing to service layer",
  "root_cause": "Implementer focused on happy path; spec did not enumerate validation requirements",
  "detection_gap": "Code quality reviewer checked type hints but not validation completeness",
  "prevention": "Add validation completeness check to code-quality-reviewer-prompt.md",
  "review_instruction": "Verify every public endpoint validates all user-supplied inputs before calling service layer",
  "applies_to": ["code-quality-reviewer"],
  "created_at": "2026-04-19T12:00:00Z",
  "updated_at": "2026-04-19T14:30:00Z",
  "promoted_at": null
}
```

**type values:**
- `auto-detected` — detected by a reviewer during a task review cycle
- `user-reported` — reported by the user during or after execution

**applies_to values:** `spec-reviewer`, `code-quality-reviewer`, `domain-reviewer` (one or more)

**status values:**
- `active` — in the ledger, not yet promoted
- `promoted` — promoted to `policies.json` and `review-standards.md`; set `promoted_at`
- `closed` — explicitly closed by user (won't recur, not worth promoting)

---

## policies.json

**Location:** `${POLICIES_FILE}` (default: `.claude/policies.json`)
**Format:** Single JSON object. Written by `policy-updater` on promotion decisions.
**Init value:** `{"version": "1", "policies": [], "updated_at": "<ISO-timestamp>"}`

```json
{
  "version": "1",
  "updated_at": "2026-04-19T15:00:00Z",
  "policies": [
    {
      "id": "P-1",
      "source_defect_id": "AD-1",
      "mode": "active",
      "rule": "Every public endpoint must validate all user-supplied inputs before calling the service layer",
      "check": "Grep for endpoint handlers without input validation; verify pydantic models or equivalent on all request bodies",
      "why": "Missing validation enabled injection attacks in 3 separate tasks before being caught at Phase 6",
      "promoted_at": "2026-04-19T15:00:00Z"
    }
  ]
}
```

**mode values:** `active` (enforced by reviewers), `shadow` (logged but not blocking)

---

## critic.json

**Location:** `${CONTEXT_DIR}/.claude/critic.json` (latest plan critique; overwritten per run)
**Format:** Single JSON object. Written by `plan-analyser` after each critique.

```json
{
  "plan_file": "docs/plans/2026-04-19-add-auth.md",
  "run_id": "add-auth-20260419120000",
  "verdict": "PROCEED_WITH_CHANGES",
  "dimensions": [
    {"id": 1, "name": "architectural_soundness", "verdict": "pass", "reason": "Approach aligns with existing patterns"},
    {"id": 2, "name": "generic_scalable_design", "verdict": "concern", "reason": "JWT secret hardcoded in config example"},
    {"id": 3, "name": "edge_cases_failures", "verdict": "pass", "reason": "Token expiry and invalid token both handled"},
    {"id": 4, "name": "scope_boundaries", "verdict": "pass", "reason": "File list explicit; blast radius bounded"},
    {"id": 5, "name": "success_criteria_ralph", "verdict": "pass", "reason": "RALPH criteria are measurable"},
    {"id": 6, "name": "sequence_dependencies", "verdict": "pass", "reason": "Tasks ordered correctly"},
    {"id": 7, "name": "topology_justification", "verdict": "pass", "reason": "Single Agent appropriate for scope"}
  ],
  "concerns": [
    {
      "dimension": 2,
      "location": "Phase 2, Step 3",
      "issue": "Config example shows JWT_SECRET hardcoded",
      "fix": "Use environment variable pattern consistent with env-config-policy.md"
    }
  ],
  "blockers": [],
  "iteration": 1,
  "generated_at": "2026-04-19T12:05:00Z"
}
```

**verdict values:** `PROCEED`, `PROCEED_WITH_CHANGES`, `BLOCK`
**dimension verdict values:** `pass`, `concern`, `blocker`

---

## validator-result.json (per-validator, per-task)

**Written by:** each validator skill
**Consumed by:** orchestrator (injects into task summary; triggers fix loop on `fail`)

```json
{
  "validator": "wiring-auditor",
  "task_id": "T-3",
  "verdict": "fail",
  "evidence": "UserService.create_user() defined at src/services/user.py:45 has no non-test caller. Tests call it directly but no router or background job routes to it.",
  "gaps": [
    "src/api/users.py: POST /users route calls old UserManager.register() — UserService.create_user() never wired in"
  ],
  "checked_at": "2026-04-19T14:35:00Z"
}
```

**verdict values:** `pass`, `fail`, `skip`
- `skip` requires a `reason` in the `evidence` field explaining why the validator is not applicable

---

## promotion-bundle.json (headless mode only)

**Written by:** `policy-updater` in headless mode
**Location:** `${CONTEXT_DIR}/promotion-bundle.json`

```json
{
  "run_id": "add-auth-20260419123456",
  "generated_at": "2026-04-19T15:00:00Z",
  "promote_recommendations": [
    {
      "defect_id": "AD-1",
      "pattern": "Missing input validation on public endpoints",
      "severity": "high",
      "occurrences": 3,
      "reason": "threshold"
    }
  ],
  "keep_recommendations": [
    {
      "defect_id": "AD-3",
      "pattern": "F-string in logger call",
      "severity": "medium",
      "occurrences": 1,
      "reason": "below threshold"
    }
  ],
  "action": "Run /policy-updater GATE_MODE=interactive to resolve, or edit .claude/policies.json manually"
}
```
