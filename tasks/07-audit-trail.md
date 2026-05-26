# Task 7 — Audit trail

## Goal
Every meaningful change to data is recorded, queryable per-forening, and tamper-evident enough to satisfy compliance and "who did what" questions.

## Prerequisites
- Task 5 (policies, so audit reads are role-gated)

## Plan

### AshEvents integration (migrated from AshPaperTrail)
- [x] `ash_events` in deps
- [x] `.formatter.exs` updated with `:ash_events` in `import_deps`
- [x] `Exhs.Audit` domain created, registered in `ash_domains`
- [x] `Exhs.Audit.EventLog` resource with `AshEvents.EventLog` extension — centralized event table (`audit_events`)
- [x] `persist_actor_primary_key :user_id` — events track which user made the change
- [x] `primary_key_type Ash.Type.UUIDv7` — time-ordered event IDs
- [x] `AshEvents.Events` extension added to: Forening, Membership, Group, MemberGroup, Subscription, Payment
- [x] All resources point `event_log` to `Exhs.Audit.EventLog`
- [x] Sensitive fields excluded from event data by default (AshEvents behavior)
- [x] Migration drops all PaperTrail `*_versions` tables, creates single `audit_events` table

### Actor capture
- [x] Actor is set on actions in web layer via Ash.Scope
- [ ] System-initiated actions (Oban workers — Task 13) use a synthetic system actor or actor=nil with marker

### Redaction
- [x] Sensitive fields excluded by default in AshEvents (no `store_sensitive_attributes` configured)
- [x] `hashed_password` never appears in event data or changed_attributes (tested)

### Admin UI hook
- [ ] Per-resource "History" panel (built in Task 17 — Admin UI)
- [ ] Forening-wide audit log view filterable by actor, resource type, date range

### GDPR considerations (cross-ref Task 18)
- [ ] Decide retention window for audit logs (likely match 5-year financial retention)
- [ ] When a user is anonymized, audit log retains action records but actor reference becomes "anonymized user"

### Future tasks should add AshEvents.Events
- [ ] Events (Task 9), Shop (Task 10), Communications (Task 11) — add `events do event_log Exhs.Audit.EventLog end`

### Event replay (future)
- [ ] Implement `clear_records_for_replay` if event sourcing needed for Billing
- [ ] Add `current_action_versions` and `replay_non_input_attribute_changes` as actions evolve

### Tests (8 tests)
- [x] Updating a membership creates an event with correct action name
- [x] Creating a group creates an event
- [x] Updating a forening creates an event
- [x] Event records the actor who made the change
- [x] Event stores input data
- [x] Events from different foreninger use distinct record IDs (isolation)
- [x] Sensitive fields not stored in event data or changed_attributes
- [x] Destroying a group creates a destroy event

## Decided
- **AshEvents over AshPaperTrail** — centralized event log, future replay capability, better fit for event-sourced domains (Billing).
- **Audit-only mode for v1** — no replay configured yet. Can add later without schema changes.
- **No tamper-evidence for v1** — no hash-linked log or S3 export. Simple DB-backed audit.
- **Single event table** — all domains share `audit_events`. Queryable by resource type, record_id, actor.

## Done when
- Every audited resource has event history ✓
- Admin can answer "who changed this membership and when" in the UI (post Task 17)
- Audit log retention policy is documented
