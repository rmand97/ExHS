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
- [ ] Wire `stripity_stripe` config in `config/runtime.exs`
- [ ] Each forening has its own Stripe Connect account? Or single platform account with metadata? **Decision needed — see open decisions**
- [ ] Stripe API version pinned

### Subscription lifecycle flow
- [ ] Code interface: `Exhs.Billing.start_kontingent_subscription/2` — creates Stripe customer (if missing), creates subscription against forening's `kontingent_stripe_price_id`, returns checkout session URL
- [ ] Code interface: `Exhs.Billing.cancel_kontingent_subscription/2` — calls Stripe, persists `cancel_at_period_end`
- [ ] On webhook `customer.subscription.updated`: sync resource, trigger Membership activation/deactivation (Task 13 worker)
- [ ] On webhook `invoice.payment_succeeded`: create Payment record

### One-time charges
- [ ] Code interface: `Exhs.Billing.create_checkout_session/3` for event ticket or order
- [ ] Webhook `checkout.session.completed` → create Payment, mark target Registration/Order as paid

### Webhook controller
- [ ] `ExhsWeb.StripeWebhookController` with signature verification
- [ ] Idempotent processing (record `stripe_event_id`, skip duplicates) — see Task 13 for queueing
- [ ] Per-forening webhook secret if using Stripe Connect

### Receipts
- [ ] Rely on Stripe-hosted receipts initially; PDF generation deferred
- [ ] Member self-service shows Stripe-hosted invoice URLs

### Policies
- [ ] Subscription: read own (member), read all (admin/board), no manual create (Stripe-driven)
- [ ] Payment: read own (member), read all (admin/board), refund (admin)

### Tests
- [ ] Use Stripe's test mode + signed webhook fixtures
- [ ] Subscription creation flow with mocked checkout
- [ ] Webhook idempotency
- [ ] Refund creates corresponding Payment update

## Open decisions
- [ ] **Stripe Connect vs platform account** — Connect gives each forening their own balance and KYC, but adds onboarding friction. Platform account is simpler but mixes funds. Strong recommendation: Connect (Standard or Express). Confirm.
- [ ] **PDF invoices** — Stripe receipts often sufficient; only build custom PDFs if foreninger demand it
- [ ] **VAT / Danish moms** — kontingent is typically VAT-exempt but tickets/merch may not be; clarify with finance/legal
- [ ] **Currency** — DKK only, or multi-currency support?
- [ ] **Failed payment retry** — Stripe Smart Retries on or custom dunning flow?

## Done when
- Member can subscribe to kontingent end-to-end (test mode)
- Webhook keeps Subscription + Membership status in sync
- Payment log shows all charges and refunds
- Admin can refund from UI (Task 17)
