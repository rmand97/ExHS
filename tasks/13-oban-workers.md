# Task 13 — Background jobs (Oban)

## Goal
All recurring and async work happens via Oban with proper queue isolation, dashboards, and tenant-aware actor context.

## Prerequisites
- Tasks 4, 8, 9, 11, 12 (the workers reference resources from these)

## Plan

### Oban configuration
- [ ] Queues defined per workload: `default`, `mailers`, `webhooks`, `stripe`, `gdpr`, `maintenance`
- [ ] Per-queue concurrency limits sized to provider rate limits
- [ ] `Oban.Pro` features? **Decide — see open decisions**

### AshOban integration
- [ ] Wire `ash_oban` so actions can be triggered via Oban with proper scope/actor
- [ ] Convention: workers build `Exhs.Scope` and pass to code-interface calls

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

#### `Exhs.Workers.StripeWebhookProcessor`
- [ ] Webhook controller enqueues job; controller returns 200 immediately
- [ ] Idempotent on `stripe_event_id`
- [ ] Dispatches by event type to appropriate sync function

#### `Exhs.Workers.GdprCleanup`
- [ ] Cron: daily
- [ ] Finds users meeting anonymization criteria (Task 18)
- [ ] Anonymizes user record while preserving financial integrity

#### `Exhs.Workers.OrphanedUploadSweeper`
- [ ] Cron: weekly
- [ ] Removes S3 objects no longer referenced by any resource

#### `Exhs.Workers.ReminderSender` (optional)
- [ ] Sends event reminders 24h before start to confirmed registrants

### Observability
- [ ] Mount Oban Web (dashboard) under `/admin/oban` for superadmin
- [ ] Telemetry events forwarded to observability stack (Task 20)
- [ ] Failure alerting

### Tests
- [ ] Each worker has a unit test that exercises happy path + at least one failure mode
- [ ] Idempotency tests for Stripe webhook processor
- [ ] Cron expression validation

## Open decisions
- [ ] **Oban Pro** — licensed features (unique jobs, batches, workflows) worth the cost? Recommendation: start free, upgrade if patterns demand it
- [ ] **Worker actor model** — synthetic `:system` actor with `is_superadmin: true`? Or actor=nil + explicit `authorize?: false`?
- [ ] **Cron storage** — `config.exs` static, or DB-stored via Oban Pro?

## Done when
- Oban dashboard mounted and reachable
- All listed workers exist with tests
- Cron jobs running on schedule in staging
- Webhook controller returns <500ms by deferring work to Oban
