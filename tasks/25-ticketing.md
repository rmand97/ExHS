# Task 25 — Ticket purchasing & checkout

## Goal

A polished, real-time ticket-buying experience for events. A member opens an
event, picks a ticket type (possibly a group-gated presale), answers any
required questions (e.g. "which year did you graduate?"), optionally adds
extras (e.g. a bus ticket), and pays through Stripe — all driven from a single
LiveView that updates availability **live** as other people buy. Free tickets
confirm instantly; paid tickets reserve the seat with a live countdown, redirect
to Stripe Checkout, and confirm via webhook.

The data model is built as an **Order + line-item** aggregate so future features
(guest tickets, more add-on types, richer questions) bolt on without reshaping
the core.

## Prerequisites

- Task 9 (Events — Event, TicketType, Registration exist)
- Task 8 (Billing — Stripe Connect, hosted Checkout, Payment log, webhook worker)
- Task 6 (Groups — Group + MemberGroup many_to_many on Membership)
- Task 13 (Oban — reservation expiry + waitlist promotion workers)
- Task 14 (design system), Task 15 (public event show), Task 16 (member "my tickets")

## Decided

- **Order + OrderItem aggregate.** An `Order` (the cart/purchase) groups one or
  more `OrderItem`s. A ticket item links/creates a `Registration`; an add-on
  item links an `AddOn`. One `Payment` per order (`Payment.payable_type: :order`,
  already in the enum). This is the extensible base for all future ticket work.
- **Hosted Stripe Checkout**, reusing the subscription path
  (`StripeClient.create_checkout_session/2` on the forening's connected account).
  LiveView drives the live cart; Stripe collects card; webhook confirms.
- **Timed reservation + live countdown.** Starting a paid checkout holds seats
  for N minutes (`held_until`). Capacity counts `confirmed` + unexpired held.
  An Oban worker releases expired holds and triggers waitlist promotion.
- **One ticket per member per ticket type for now** (keep the
  `one_per_ticket_type` identity). Model carries `quantity` (default 1) and a
  future `TicketType.allow_multiple` toggle, but v1 enforces 1.
- **Group-gated ticket types.** A ticket type can be restricted to one or more
  groups via a join. If gated, only members in an eligible group may buy. A
  per-ticket-type sales window (`sales_starts_at`/`sales_ends_at`) plus the
  existing `capacity` gives presales like "200 tickets for graduates of 2010".
- **Custom questions** live on the ticket type (`TicketTypeQuestion`); answers
  are stored per item in `OrderItem.responses` (jsonb). Group/year selection is
  modeled as a question, not a bespoke column.

## Plan

### TicketType extensions (Events domain)
- [ ] Add `sales_starts_at`, `sales_ends_at` (nullable = falls back to event window)
- [ ] Add `allow_multiple` (bool, default false) — placeholder for future quantity; v1 enforces qty 1
- [ ] `many_to_many :eligible_groups, Group through TicketTypeGroup` join (`event_ticket_type_groups`, tenant-scoped, unique `(ticket_type_id, group_id)`)
- [ ] Code interface: `set_ticket_type_groups`, `list_ticket_type_questions`
- [ ] Calculation/aggregate: `seats_taken` (confirmed + unexpired held) and `seats_left` (capacity - seats_taken, nil capacity = unlimited)

### TicketTypeQuestion resource
- [ ] `Exhs.Events.TicketTypeQuestion` at `lib/exhs/events/ticket_type_question.ex`
- [ ] Multitenancy `:attribute` on `forening_id`; `belongs_to :ticket_type`
- [ ] Attributes: `label`, `field_type` (atom: `:text | :select | :number`), `options` ({:array, :string}, for `:select`), `required` (bool), `position`, timestamps
- [ ] Policies: read for members; CRUD admin only

### AddOn resource (extras, e.g. bus ticket)
- [ ] `Exhs.Events.AddOn` at `lib/exhs/events/add_on.ex`
- [ ] Multitenancy `:attribute` on `forening_id`; `belongs_to :event`
- [ ] Attributes: `name`, `description`, `price_cents`, `currency`, `capacity` (nullable), timestamps
- [ ] Policies: read for members; CRUD admin only

### Order resource
- [ ] `Exhs.Events.Order` at `lib/exhs/events/order.ex`
- [ ] Multitenancy `:attribute` on `forening_id`; `belongs_to :membership`, `belongs_to :event`
- [ ] Attributes: `status` (atom: `:building | :pending_payment | :paid | :cancelled | :expired`), `total_cents`, `currency`, `held_until` (utc_datetime_usec), `stripe_checkout_session_id`, `paid_at`, timestamps
- [ ] `has_many :items, OrderItem`; `has_one :payment` (via `payable_type: :order`, `payable_id`)
- [ ] Code interface: `create_order`, `add_order_item`, `remove_order_item`, `checkout_order`, `cancel_order`, `get_order`, `mark_order_paid`, `expire_order`

### OrderItem resource
- [ ] `Exhs.Events.OrderItem` at `lib/exhs/events/order_item.ex`
- [ ] Multitenancy `:attribute` on `forening_id`; `belongs_to :order`
- [ ] Attributes: `item_type` (atom: `:ticket | :addon`), `quantity` (default 1), `unit_price_cents` (snapshot), `responses` (:map, jsonb — answers keyed by question id)
- [ ] Nullable refs: `ticket_type_id`, `add_on_id`, `registration_id` (ticket items link the created Registration)
- [ ] Validation: ticket item requires `ticket_type_id`; addon item requires `add_on_id`
- [ ] Validation: required questions for the ticket type are answered in `responses`

### Reservation / capacity holds
- [ ] Registration gains status `:reserved` and `held_until` (or reuse `:pending_payment` + `held_until` — pick one in implementation)
- [ ] `CheckCapacity` change updated: count `confirmed` + held-and-unexpired against `capacity`; oversell → `:waitlisted` (free) or reject (paid presale)
- [ ] Oban worker `Exhs.Events.ReservationExpiry` (Task 13): on `held_until` expiry, release the hold, cancel the order, enqueue `WaitlistPromoter`
- [ ] `checkout_order` sets `held_until = now + N min`, reserves seats, returns Stripe Checkout URL

### Eligibility & validation
- [ ] Extend `Exhs.Events.Validations.RegistrationAllowed`: enforce ticket-type sales window and group eligibility (`membership ∈ eligible_groups` when gated)
- [ ] Free ticket order → confirm immediately, no Stripe (skip payment)
- [ ] Paid ticket order → reserve, checkout, confirm on webhook
- [ ] Enforce `quantity = 1` unless `ticket_type.allow_multiple` (future); one-per-member identity still applies

### Stripe wiring (Billing)
- [ ] `checkout_order` builds Checkout line items from order items (ticket + add-ons), creates session on forening's connected account, stores `stripe_checkout_session_id`
- [ ] Wire `checkout.session.completed` in `Exhs.Billing.Webhook` (currently a no-op): look up order by session id → `mark_order_paid` → confirm registrations → `record_payment` (`payable_type: :order`)
- [ ] `charge.refunded` already handled for Payment; ensure order/registration reflect refund
- [ ] Idempotency via existing Oban unique job on `stripe_event_id`

### LiveView purchase experience (leverage liveness)
- [ ] Rework `ExhsWeb.PublicLive.Events.Show` purchase panel — replace the dead `href="#"` "Tilmeld" with a real multi-step flow in one LiveView: select ticket → answer questions → choose add-ons → review → pay
- [ ] **Live availability**: PubSub topic per event; broadcast on reserve/confirm/release so all viewers see `seats_left` update in real time (e.g. "kun 3 tilbage")
- [ ] **Live countdown**: while held, show a ticking `held_until` timer; auto-expire UI and re-enable purchase when it lapses
- [ ] **Live waitlist**: show waitlist position; update when promoted
- [ ] Group-gated tickets render a presale badge and hide/disable for ineligible members with a clear reason
- [ ] On free ticket: confirm in place, no redirect. On paid: redirect to Stripe, return to a confirmation LiveView
- [ ] `ExhsWeb.MemberLive` — "Mine billetter" / order confirmation + receipt (Stripe-hosted), live status

### Admin UI (Task 17 surface)
- [ ] Admin manages ticket types: price, capacity, sales window, eligible groups, questions, add-ons
- [ ] Admin sees live sales/availability per ticket type (sold / held / left / waitlisted)

### Seeds
- [ ] Extend `priv/repo/seeds.exs` (idempotent): a paid event with a normal ticket type, a **group-gated presale** ticket type (200 cap, tied to a "Graduates of 2010" group), an add-on (bus ticket), and a couple of questions (graduation year select). Pre-populate a sample paid order.

### Migrations
- [ ] `mix ash.codegen --dev` iteratively, final `mix ash.codegen ticketing`

### Tests
Tenant isolation, external dep (Stripe), and LiveView interactivity all apply — test thoroughly per CLAUDE.md.

- [ ] **Tenant isolation**: two foreninger, orders/ticket types in both, each sees only its own; cross-tenant order/ticket-type IDs rejected (list, show, mutations)
- [ ] **Group gating**: member NOT in eligible group rejected; member IN group succeeds; ungated ticket open to all
- [ ] **Sales window**: before `sales_starts_at` rejected; after `sales_ends_at` rejected; inside window OK
- [ ] **Capacity with holds**: 200-cap presale — holds count toward capacity; oversell prevented; last seat race resolves to one buyer
- [ ] **Hold expiry**: expired hold releases seat (Oban worker), order → `:expired`, waitlist promoted
- [ ] **Free ticket**: confirms instantly, no Payment, no Stripe call
- [ ] **Paid ticket (Stripe via `StripeClient.Stub`)**: order → checkout session created → `checkout.session.completed` webhook → order paid, registration confirmed, Payment recorded (`:order`)
- [ ] **Webhook**: signature rejection, idempotency (same event twice), failure path (declined/timeout) leaves no half-committed state
- [ ] **Add-on**: bus add-on included in order total and Checkout line items
- [ ] **Questions**: required question unanswered → rejected; answers persisted in `OrderItem.responses`
- [ ] **One-per-member**: duplicate ticket for same member/ticket type rejected
- [ ] **LiveView** (`Phoenix.LiveViewTest`): mounts; full purchase flow (select → answer → review → pay) works; ineligible member sees gated reason; **live availability updates** — second test process buys, assert first viewer's `seats_left` decrements via PubSub; countdown renders while held

## Open decisions

- [ ] **Hold duration N** — 10 min? configurable per forening or event?
- [ ] **Refund → seat** — refunding a paid ticket frees the seat and auto-promotes waitlist, or admin-manual?
- [ ] **Add-on without ticket** — can someone buy only a bus ticket, or must it accompany a ticket?
- [ ] **Guest/multiple tickets** — future task; `allow_multiple` + per-attendee info capture deferred
- [ ] **Question types** — start with text/select/number; date/checkbox later?
- [ ] **VAT/moms on tickets & add-ons** — tickets may be VAT-liable unlike kontingent (see Task 8)

## Done when

- Member buys a free ticket end-to-end (instant confirm, no Stripe)
- Member buys a paid ticket + add-on end-to-end (reserve → Stripe Checkout → webhook confirm → receipt)
- A group-gated presale (e.g. 200 tickets, "Graduates of 2010") sells only to eligible members and stops at capacity
- Availability and hold countdown update **live** across concurrent viewers
- Reservations expire and release seats automatically; waitlist promotes
- Tenant isolation verified; Stripe paths tested against the stub
