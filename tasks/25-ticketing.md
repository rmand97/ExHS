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

Tenant isolation, external dep (Stripe), and LiveView interactivity all apply — test thoroughly per CLAUDE.md. Test through code interfaces (the real caller entry point), not internals. Each area below lists happy paths and the bad paths that must fail loudly. Two foreninger seeded in every isolation-sensitive test.

#### Order lifecycle (code interface)
Happy:
- [ ] `create_order` → `:building`, zero total, linked to membership + event
- [ ] `add_order_item` (ticket) → recomputes `total_cents` from `unit_price_cents` snapshot; item links/creates Registration
- [ ] `add_order_item` (addon) → total includes add-on price
- [ ] `remove_order_item` → total recomputed; removing last item leaves empty `:building` order
- [ ] `cancel_order` from `:building` / `:pending_payment` → `:cancelled`, any held seats released
- [ ] `get_order` returns order with items + payment loaded

Bad:
- [ ] `add_order_item` to a non-`:building` order (`:paid`/`:cancelled`/`:expired`) rejected
- [ ] `checkout_order` on empty order rejected
- [ ] `unit_price_cents` is a snapshot — later ticket-type price change does NOT mutate an existing order total
- [ ] mutate someone else's order (other membership) rejected by policy

#### OrderItem validation
Happy:
- [ ] ticket item with `ticket_type_id` valid; addon item with `add_on_id` valid
- [ ] required questions answered → item persists; `responses` stored keyed by question id

Bad:
- [ ] ticket item missing `ticket_type_id` rejected; addon item missing `add_on_id` rejected
- [ ] item with both `ticket_type_id` and `add_on_id` rejected
- [ ] required question unanswered → rejected
- [ ] answer for `:select` question not in `options` → rejected
- [ ] answer wrong type (text for `:number`) → rejected
- [ ] `quantity > 1` when `allow_multiple = false` → rejected (v1 enforces 1)

#### Group gating
- [ ] ungated ticket type: any member buys (happy)
- [ ] gated, member IN an eligible group: buys (happy)
- [ ] gated, member NOT in any eligible group: rejected with clear reason (bad)
- [ ] gated to multiple groups, member in one of them: buys (happy)
- [ ] member removed from group after gating: subsequent buy rejected (bad)

#### Sales window
- [ ] inside window (`sales_starts_at` < now < `sales_ends_at`): buys (happy)
- [ ] before `sales_starts_at`: rejected (bad)
- [ ] after `sales_ends_at`: rejected (bad)
- [ ] null window falls back to event window: respects event start/end (happy + bad either side)

#### Capacity & holds
- [ ] `seats_taken` counts `confirmed` + unexpired held; `seats_left = capacity - seats_taken`
- [ ] nil capacity = unlimited, never blocks (happy)
- [ ] hold counts toward capacity: last seat held → next buyer blocked even before payment (bad)
- [ ] free oversell → `:waitlisted`; paid presale oversell → rejected
- [ ] **last-seat race**: two concurrent `checkout_order` on a 1-left ticket type — exactly one wins, other rejected/waitlisted (no oversell)
- [ ] expired hold no longer counts toward capacity (seat reusable)

#### Hold expiry (Oban `ReservationExpiry`)
- [ ] worker on `held_until` lapse: releases hold, order → `:expired`, Registration hold cleared (happy)
- [ ] expiry enqueues `WaitlistPromoter`; next waitlisted member promoted (happy)
- [ ] worker is idempotent — running twice on same order no double-promote, no error
- [ ] worker does NOT expire an already-`:paid` order (bad/guard)

#### Free ticket
- [ ] free ticket order confirms instantly: order → `:paid` (or `:confirmed`), Registration `:confirmed`, no `held_until`
- [ ] NO Stripe call made (assert stub not invoked)
- [ ] NO Payment row created for a zero-total order

#### Paid ticket + Stripe (`StripeClient.Stub`)
Happy:
- [ ] `checkout_order` builds line items (ticket + add-ons) on forening's connected account, stores `stripe_checkout_session_id`, sets `held_until = now + N`, order → `:pending_payment`
- [ ] `checkout.session.completed` webhook → `mark_order_paid`, Registrations `:confirmed`, Payment recorded (`payable_type: :order`), `paid_at` set, hold cleared
- [ ] add-on appears as a distinct Checkout line item and in order total

Bad:
- [ ] webhook with bad signature rejected, no state change
- [ ] same `checkout.session.completed` delivered twice → idempotent (Oban unique on `stripe_event_id`), single Payment, no double-confirm
- [ ] webhook for unknown / cross-tenant session id → no-op, no crash
- [ ] Stripe session creation failure (stub returns error) → order stays `:building`/`:pending_payment`, no seat permanently lost, surfaced to caller
- [ ] `checkout.session.expired` / abandoned checkout → hold released on expiry (ties to Oban worker)
- [ ] `charge.refunded` → Payment refunded AND order/registration reflect refund (seat freed per decided behavior)

#### One-per-member identity
- [ ] duplicate ticket, same member + same ticket type → rejected (bad)
- [ ] same member, DIFFERENT ticket type same event → allowed (happy)
- [ ] member can re-buy after their order cancelled/expired (identity not blocked by dead order) (happy)

#### Tenant isolation
- [ ] orders/ticket types/add-ons in both foreninger: each forening lists only its own
- [ ] `get_order` with cross-tenant id → not found
- [ ] cross-tenant `checkout_order` / `add_order_item` / `cancel_order` → rejected
- [ ] cross-tenant ticket type id in `add_order_item` → rejected
- [ ] webhook resolves order within correct tenant only

#### LiveView (`Phoenix.LiveViewTest`)
Happy:
- [ ] purchase panel mounts on event show
- [ ] full flow: select ticket → answer questions → choose add-ons → review → pay (free path confirms in place; paid path redirects to Stripe URL)
- [ ] **live availability**: second process buys/reserves → first viewer's `seats_left` decrements via PubSub ("kun N tilbage")
- [ ] **live countdown**: held order shows ticking `held_until` timer
- [ ] **live release**: hold expires → first viewer's UI re-enables purchase, seats restored
- [ ] **live waitlist**: promotion updates waitlist position for the viewer

Bad / guard:
- [ ] ineligible (gated) member: ticket disabled with reason badge, submit blocked server-side too
- [ ] outside sales window: purchase disabled with reason
- [ ] sold out: purchase disabled, waitlist CTA shown (free) / blocked (paid presale)
- [ ] required question left blank: form re-renders with error, no order created
- [ ] unauthenticated / non-member viewer: cannot purchase (redirect / disabled)

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
