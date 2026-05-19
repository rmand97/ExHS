# Task 7 — Audit trail

## Goal
Every meaningful change to data is recorded, queryable per-forening, and tamper-evident enough to satisfy compliance and "who did what" questions.

## Prerequisites
- Task 5 (policies, so audit reads are role-gated)

## Plan

### ash_paper_trail integration
- [ ] Confirm `ash_paper_trail` in deps
- [ ] Add `extensions: [AshPaperTrail.Resource]` to every resource that should be audited:
  - [ ] Forening, Membership, Group, MemberGroup
  - [ ] (Future) Subscription, Payment, Event, TicketType, Registration, Product, Order, Newsletter, Segment
- [ ] Decide on storage strategy: `change_tracking_mode :changes_only` vs `:snapshot`
- [ ] Configure store_action_name? `true` so audit shows which action ran
- [ ] Configure store_action_inputs? — capture inputs but redact sensitive args

### Audit domain
- [ ] `Exhs.Audit` domain module
- [ ] Code interface to list version history per-resource with tenant scoping
- [ ] Code interface to query "all changes by actor X in forening Y between dates"

### Actor capture
- [ ] Ensure actor is always set on actions in web layer (via Ash.Scope)
- [ ] System-initiated actions (Oban workers — Task 13) use a synthetic system actor or actor=nil with marker

### Redaction
- [ ] Never log raw passwords, tokens, Stripe secrets, PII beyond what's necessary
- [ ] Define a `sensitive_attributes` allowlist convention; AGENTS.md note

### Admin UI hook
- [ ] Per-resource "History" panel (built in Task 17 — Admin UI)
- [ ] Forening-wide audit log view filterable by actor, resource type, date range

### GDPR considerations (cross-ref Task 18)
- [ ] Decide retention window for audit logs (likely match 5-year financial retention)
- [ ] When a user is anonymized, audit log retains action records but actor reference becomes "anonymized user"

### Tests
- [ ] Updating a Membership creates a version record
- [ ] Version records are scoped to forening (admin of A can't see audit for B)
- [ ] Sensitive fields not stored in change payload

## Open decisions
- [ ] **changes_only vs snapshot** — snapshots are heavier but easier to query for state-at-time-T
- [ ] **Tamper-evidence** — do we need cryptographic chaining (hash-linked log)? Probably overkill for v1
- [ ] **External audit sink** — ship a copy to S3 / external log store for compliance defense in depth?

## Done when
- Every audited resource has version history
- Admin can answer "who changed this membership and when" in the UI (post Task 17)
- Audit log retention policy is documented
