# Task 8 — Billing & Stripe

## Goal
Stripe-backed yearly kontingent subscriptions and one-time charges (event tickets, merch). Single unified `Payment` log. Webhook-driven state sync.

## Prerequisites
- Task 4 (Membership), Task 5 (policies), Task 7 (audit)

## Plan

### Billing domain
- [ ] `Exhs.Billing` domain module
- [ ] Register in `ash_domains`

### Subscription resource
- [ ] `Exhs.Billing.Subscription` at `lib/exhs/billing/subscription.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] `belongs_to :membership` (one active subscription per membership)
- [ ] Attributes: `stripe_subscription_id`, `stripe_customer_id`, `status` (atom: `:trialing | :active | :past_due | :canceled | :incomplete`), `current_period_start`, `current_period_end`, `cancel_at_period_end` (bool), timestamps
- [ ] Identity: unique `stripe_subscription_id`
- [ ] Change module `SyncFromStripe` to apply Stripe webhook payload to resource

### Payment resource
- [ ] `Exhs.Billing.Payment` at `lib/exhs/billing/payment.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] Polymorphic-ish: `payable_type` (atom: `:subscription | :registration | :order`) + `payable_id`
- [ ] Attributes: `amount_cents`, `currency`, `status` (`:pending | :succeeded | :failed | :refunded`), `stripe_payment_intent_id`, `stripe_charge_id`, `description`, `paid_at`, timestamps
- [ ] Code interface: `record_payment`, `mark_refunded`

### Stripe configuration
- [x] Wire `stripity_stripe` config in `config/runtime.exs`
- [ ] Stripe API version pinned
- [ ] `Exhs.Billing.Stripe` thin wrapper module with a behaviour, so tests inject a mock and never call real Stripe

### Connect onboarding (per-forening)
- [ ] Forening gains `stripe_account_id` and `stripe_account_status` (atom: `:none | :onboarding | :active | :restricted`)
- [ ] Code interface: `Exhs.Billing.start_onboarding/2` — creates connected account (if missing), returns Stripe-hosted Account Link URL
- [ ] On webhook `account.updated`: sync `stripe_account_status` on the relevant Forening
- [ ] Admin LiveView to trigger onboarding lives in Task 17

### Subscription lifecycle flow
- [ ] Membership gains `stripe_customer_id` (one customer per (member, forening) on the forening's connected account)
- [ ] Code interface: `Exhs.Billing.start_kontingent_subscription/2` — ensures Stripe customer exists on connected account, creates Checkout Session against forening's `kontingent_stripe_price_id`, returns hosted URL
- [ ] Code interface: `Exhs.Billing.cancel_kontingent_subscription/2` — calls Stripe, persists `cancel_at_period_end`
- [ ] On webhook `customer.subscription.created|updated|deleted`: sync resource, trigger Membership activation/deactivation
- [ ] On webhook `invoice.payment_succeeded|payment_failed`: create/update Payment record

### One-time charges (deferred)
- [ ] Deferred until Tasks 9 (Events) and 10 (Shop) exist; `payable_type` polymorphism is left as a forward-compatible attribute on Payment but no event/order code paths wire up yet

### Webhook controller
- [ ] `ExhsWeb.StripeWebhookController` with signature verification against the single Connect webhook secret
- [ ] Single Connect endpoint; `account` field on the event determines the forening
- [ ] Idempotency via Oban unique job keyed on `stripe_event_id` (Task 13 minimum Oban setup is already in place)
- [ ] Worker `Exhs.Billing.WebhookWorker` dispatches by event type

### Receipts
- [ ] Rely on Stripe-hosted receipts initially; PDF generation deferred
- [ ] Member self-service shows Stripe-hosted invoice URLs

### Policies
- [ ] Subscription: read own (member), read all (admin/board), no manual create (Stripe-driven)
- [ ] Payment: read own (member), read all (admin/board), refund (admin)

### Tests
External dep — test thoroughly. Never hit real Stripe.

**Unit suite (default, pure-Elixir):** orchestrator + webhook logic tested against `Exhs.Billing.StripeClient.Stub` injected via Application config. Fast, no Docker.

**Integration suite (`@tag :integration`, deferred wiring):** later, point `stripity_stripe` at a `stripe-mock` Docker service to exercise the real client against realistic Stripe responses. Catches schema/contract drift the stub can miss.

- [ ] Subscription creation flow (happy path) with stub
- [ ] Webhook signature verification rejects invalid/expired signatures
- [ ] Webhook idempotency (same event id arriving twice does nothing the second time)
- [ ] All relevant event types covered: `checkout.session.completed`, `invoice.payment_succeeded`, `invoice.payment_failed`, `customer.subscription.deleted`, refunds
- [ ] Refund creates corresponding Payment update
- [ ] Failure paths: API timeout, API 5xx, declined card — verify we surface a sensible error and don't half-commit state
- [ ] Reconciliation job: drift between Stripe and our DB is detected and logged (Task 13)
- [ ] **Follow-up:** stand up `stripe-mock` (via Aspire + Docker), add `@tag :integration` suite that toggles `:stripe_client` back to `Live` for contract coverage

## Decided

- **Stripe Connect Standard** — each forening has its own connected account. Single platform-side Connect webhook endpoint; `account` field on the event identifies the forening.
- **Currency: DKK only** for now. The `kontingent_currency` field stays on Forening but is validated to `"DKK"`.
- **Customer model: one Stripe Customer per Membership** on the relevant forening's connected account. `stripe_customer_id` lives on `Membership`.
- **Webhook idempotency: Oban** — webhook controller verifies signature, enqueues a unique Oban job keyed on `stripe_event_id`; Oban's uniqueness handles dedup.
- **One-time charges deferred** until Tasks 9/10 introduce Events and Orders. `Payment.payable_type` stays polymorphic but only `:subscription` is wired.
- **Reconciliation job deferred** to Task 13.

## Open decisions
- [ ] **PDF invoices** — Stripe receipts often sufficient; only build custom PDFs if foreninger demand it
- [ ] **VAT / Danish moms** — kontingent is typically VAT-exempt but tickets/merch may not be; clarify with finance/legal
- [ ] **Failed payment retry** — Stripe Smart Retries on or custom dunning flow?
- [ ] **Connect account type** — Standard chosen; revisit if onboarding friction is a problem (could move to Express)

## Done when
- Member can subscribe to kontingent end-to-end (test mode)
- Webhook keeps Subscription + Membership status in sync
- Payment log shows all charges and refunds
- Admin can refund from UI (Task 17)
