# Task 13 — Background jobs (Oban)

## Goal
All recurring and async work happens via Oban with proper queue isolation, dashboards, and tenant-aware actor context.

## Prerequisites
- Tasks 4, 8, 9 (the workers reference resources from these)
- Tasks 11, 12 deferred to nice-to-have — workers depending on them are deferred too

## Plan

### Oban configuration
- [x] Queues defined per workload: `default`, `mailers`, `webhooks`, `stripe`, `gdpr`, `maintenance`
- [x] Per-queue concurrency limits sized to provider rate limits
- [x] Pruner plugin (7-day retention)

### AshOban integration
- [x] `AshOban.config/2` wrapping Oban config in `application.ex`
- [ ] `AshOban` extension + triggers on resources that need background processing
- [ ] `AshOban.Checks.AshObanInteraction` bypass in policies on triggered resources

### Workers

#### `Exhs.Workers.MembershipDeactivator`
- [ ] Cron: daily
- [ ] Finds memberships whose subscription lapsed past grace period → marks `:inactive`
- [ ] Emits audit log entry

#### `Exhs.Workers.WaitlistPromoter`
- [ ] Triggered on registration cancellation
- [ ] Promotes first waitlisted registration in FIFO order
- [ ] Sends confirmation email

#### `Exhs.Workers.NewsletterSender`
- [ ] Triggered when newsletter scheduled
- [ ] Fans out per-recipient sub-jobs respecting provider rate limits
- [ ] Handles bounces, retries

#### `Exhs.Billing.WebhookWorker` (done — Task 8)
- [x] Webhook controller enqueues job; controller returns 200 immediately
- [x] Idempotent on `stripe_event_id` (unique: period: :infinity)
- [x] Dispatches by event type via `Exhs.Billing.Webhook.apply_event/1`

#### Deferred workers (dependencies not ready)
- [ ] `GdprCleanup` — daily cron, anonymize lapsed users (Task 18)
- [ ] `OrphanedUploadSweeper` — weekly cron, remove unreferenced S3 objects (Task 12)
- [ ] `NewsletterSender` — fan-out per-recipient (Task 11, nice-to-have)
- [ ] `ReminderSender` — event reminders 24h before start (needs email, optional)

### Observability
- [ ] Mount Oban Web (dashboard) under `/admin/oban` for superadmin
- [ ] Telemetry events forwarded to observability stack (Task 20)
- [ ] Failure alerting

### Tests
- [ ] Each worker has a unit test that exercises happy path + at least one failure mode
- [ ] Idempotency tests for Stripe webhook processor
- [ ] Cron expression validation

## Open decisions
(none remaining)

## Decided
- **Free Oban** — no Oban Pro. Unique jobs handled manually (`unique` option on workers). No batches/workflows needed.
- **AshObanInteraction bypass** — resources with triggers get `bypass AshOban.Checks.AshObanInteraction do authorize_if always() end` in policies. No synthetic actor, no global `authorize?: false`.
- **Static cron** — schedules in `config.exs` via `Oban.Plugins.Cron`. Redeploy for changes is acceptable; no admin-configurable schedules needed.

## Done when
- Oban dashboard mounted and reachable
- All listed workers exist with tests
- Cron jobs running on schedule in staging
- Webhook controller returns <500ms by deferring work to Oban
