# Task 18 — GDPR & data retention

## Goal
Defensible compliance posture: data minimization, right to access, right to erasure (with financial-record preservation), retention windows enforced by code, cookie consent.

## Prerequisites
- Tasks 3, 4, 7, 8, 13 (workers)

## Plan

### Legal basis mapping
- [ ] Document the legal basis for each piece of personal data (contract, legitimate interest, consent)
- [ ] Reviewed against Danish DPA guidance

### Data inventory
- [ ] Catalog every resource holding personal data; track in `docs/gdpr/data-inventory.md`
- [ ] For each: legal basis, retention window, deletion/anonymization strategy

### Right to access (data portability)
- [ ] User action: `request_data_export`
- [ ] Oban job generates JSON bundle of all user-related data across all foreninger they're in
- [ ] Delivered via signed S3 link (expires in 7 days)

### Right to erasure
- [ ] User action: `request_account_deletion` (or admin-initiated)
- [ ] Anonymize approach (not hard delete) because financial records must persist for Bogføringsloven (5 years)
- [ ] On anonymize: User PII fields → null/redacted; preserve `id`; email → `anonymized-{uuid}@deleted.exhs.dk`; avatar deleted
- [ ] Memberships marked terminated but kept linked to (now-anonymized) user for audit/financial integrity
- [ ] Audit log retains "anonymized user X" reference, not original PII

### Retention enforcement
- [ ] Configurable per-forening inactivity threshold (default e.g. 24 months) after which the inactive member is offered anonymization
- [ ] Oban worker `GdprCleanup` (Task 13) finds candidates, notifies them, anonymizes after grace period
- [ ] Hard-coded retention: financial records 5 years (Bogføringsloven), audit logs match

### Cookie consent
- [ ] Banner on public pages (Task 15)
- [ ] Functional cookies (session, CSRF) — no consent needed
- [ ] Analytics cookies — opt-in
- [ ] Consent record stored with timestamp + version of consent text

### Data processing agreements
- [ ] DPA template for foreninger (we're processor for member data; forening is controller) — legal sign-off
- [ ] DPA list of sub-processors: Stripe, S3 provider, email provider, hosting

### Breach response runbook
- [ ] `docs/gdpr/breach-runbook.md`
- [ ] 72-hour DPA notification flow documented

### Tests
- [ ] Anonymize action redacts PII and leaves financial trail
- [ ] Export bundle includes all known PII for a user
- [ ] Anonymized user cannot log in / cannot be looked up by old email

## Open decisions
- [ ] **Default inactivity threshold** — 12 months? 24? Per-forening configurable
- [ ] **Anonymization vs deletion of audit log entries** — anonymize is safer
- [ ] **Cookie consent vendor** — build in-house or use Cookiebot / Klaro?

## Done when
- Documented data inventory matches code
- Self-serve data export and account deletion work
- Cookie banner present and respected
- DPA template available for foreninger
