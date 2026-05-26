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

#### `Exhs.Billing.MembershipDeactivator`
- [x] Cron: daily at 03:00 UTC
- [x] Iterates all foreninger, finds canceled/past_due subscriptions past period end
- [x] Deactivates active memberships whose subscription lapsed
- [x] Audit logged via AshEvents on deactivate action

#### `Exhs.Events.WaitlistPromoter`
- [x] Triggered on registration cancellation (after_action enqueues job)
- [x] Promotes first waitlisted registration in FIFO order
- [ ] Sends confirmation email (needs Task 11)

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
- [x] Mount Oban Web dashboard at `/dev/oban` (dev_routes; move behind superadmin auth in Task 17)
- [ ] Telemetry events forwarded to observability stack (Task 20)
- [ ] Failure alerting (Task 20)

### Tests
- [x] Each worker has unit tests: WaitlistPromoter (3), MembershipDeactivator (5), WebhookWorker (3)
- [x] Idempotency test for WebhookWorker (same event_id → same job)
- [x] Cron expression: static in config, no runtime validation needed

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
