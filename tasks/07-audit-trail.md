# Task 7 — Audit trail

## Goal
Every meaningful change to data is recorded, queryable per-forening, and tamper-evident enough to satisfy compliance and "who did what" questions.

## Prerequisites
- Task 5 (policies, so audit reads are role-gated)

## Plan

### ash_paper_trail integration
- [x] `ash_paper_trail` in deps (already was)
- [x] `.formatter.exs` updated with `:ash_paper_trail` in `import_deps`
- [x] `AshPaperTrail.Resource` extension added to: Forening, Membership, Group, MemberGroup
- [x] `AshPaperTrail.Domain` extension added to Organizations domain with `include_versions? true`
- [x] `change_tracking_mode :changes_only` — only store changed fields
- [x] `store_action_name? true` — version records which action ran
- [x] `sensitive_attributes :ignore` — sensitive fields excluded from version payload
- [x] `only_when_changed? true` — skip versions when no actual changes occurred
- [x] `reference_source? false` — no FK from version to source (supports hard deletes)
- [x] `belongs_to_actor :user` — versions track which user made the change
- [x] `attributes_as_attributes [:forening_id]` on tenant-scoped resources for multitenancy

### Actor capture
- [x] Actor is set on actions in web layer via Ash.Scope
- [ ] System-initiated actions (Oban workers — Task 13) use a synthetic system actor or actor=nil with marker

### Redaction
- [x] `sensitive_attributes :ignore` on all paper_trail configs
- [x] `hashed_password` never appears in version payloads (tested)

### Admin UI hook
- [ ] Per-resource "History" panel (built in Task 17 — Admin UI)
- [ ] Forening-wide audit log view filterable by actor, resource type, date range

### GDPR considerations (cross-ref Task 18)
- [ ] Decide retention window for audit logs (likely match 5-year financial retention)
- [ ] When a user is anonymized, audit log retains action records but actor reference becomes "anonymized user"

### Future tasks should add AshPaperTrail
- [ ] Events (Task 9), Shop (Task 10), Communications (Task 11), Billing (Task 8)

### Tests (7 tests)
- [x] Updating a membership creates a version record with correct action name
- [x] Creating a group creates a version record
- [x] Updating a forening creates a version record
- [x] Version records the actor who made the change
- [x] changes_only mode only stores changed fields (not unchanged ones)
- [x] Version records are scoped to forening (tenant isolation)
- [x] Sensitive fields not stored in change payload

## Decided
- **changes_only** — lighter storage, sufficient for "who changed what". No snapshots.
- **No tamper-evidence for v1** — no hash-linked log or S3 export. Simple DB-backed audit.
- **No cryptographic chaining** — overkill for v1.

## Done when
- Every audited resource has version history ✓
- Admin can answer "who changed this membership and when" in the UI (post Task 17)
- Audit log retention policy is documented
