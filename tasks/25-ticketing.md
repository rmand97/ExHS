# Task 25 — Ticket purchasing & checkout

> **Status: Done (2026-06-05).** Full Order + OrderItem aggregate, group-gated
> presales, custom questions, add-ons, timed holds, free instant-confirm + paid
> Stripe Checkout, webhook confirm/refund, `ReservationExpiry` Oban worker, live
> availability via PubSub, hold countdown, buyer purchase flow, member order
> views, and admin management (price/capacity/sales window/eligible groups/
> questions/add-ons + live sold/left stats). 483 tests pass; credo --strict
> clean. Decided open questions: hold N = 10 min fixed; refund auto-frees seat +
> promotes waitlist; add-ons must accompany a ticket. Not done: surfacing live
> **waitlist position** in the buyer LiveView (the two unchecked items below).

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
- [x] Add `sales_starts_at`, `sales_ends_at` (nullable = falls back to event window)
- [x] Add `allow_multiple` (bool, default false) — placeholder for future quantity; v1 enforces qty 1
- [x] `many_to_many :eligible_groups, Group through TicketTypeGroup` join (`event_ticket_type_groups`, tenant-scoped, unique `(ticket_type_id, group_id)`)
- [x] Code interface: `set_ticket_type_groups`, `list_ticket_type_questions`
- [x] Calculation/aggregate: `seats_taken` (confirmed + unexpired held) and `seats_left` (capacity - seats_taken, nil capacity = unlimited)

### TicketTypeQuestion resource
- [x] `Exhs.Events.TicketTypeQuestion` at `lib/exhs/events/ticket_type_question.ex`
- [x] Multitenancy `:attribute` on `forening_id`; `belongs_to :ticket_type`
- [x] Attributes: `label`, `field_type` (atom: `:text | :select | :number`), `options` ({:array, :string}, for `:select`), `required` (bool), `position`, timestamps
- [x] Policies: read for members; CRUD admin only

### AddOn resource (extras, e.g. bus ticket)
- [x] `Exhs.Events.AddOn` at `lib/exhs/events/add_on.ex`
- [x] Multitenancy `:attribute` on `forening_id`; `belongs_to :event`
- [x] Attributes: `name`, `description`, `price_cents`, `currency`, `capacity` (nullable), timestamps
- [x] Policies: read for members; CRUD admin only

### Order resource
- [x] `Exhs.Events.Order` at `lib/exhs/events/order.ex`
- [x] Multitenancy `:attribute` on `forening_id`; `belongs_to :membership`, `belongs_to :event`
- [x] Attributes: `status` (atom: `:building | :pending_payment | :paid | :cancelled | :expired`), `total_cents`, `currency`, `held_until` (utc_datetime_usec), `stripe_checkout_session_id`, `paid_at`, timestamps
- [x] `has_many :items, OrderItem`; `has_one :payment` (via `payable_type: :order`, `payable_id`)
- [x] Code interface: `create_order`, `add_order_item`, `remove_order_item`, `checkout_order`, `cancel_order`, `get_order`, `mark_order_paid`, `expire_order`

### OrderItem resource
- [x] `Exhs.Events.OrderItem` at `lib/exhs/events/order_item.ex`
- [x] Multitenancy `:attribute` on `forening_id`; `belongs_to :order`
- [x] Attributes: `item_type` (atom: `:ticket | :addon`), `quantity` (default 1), `unit_price_cents` (snapshot), `responses` (:map, jsonb — answers keyed by question id)
- [x] Nullable refs: `ticket_type_id`, `add_on_id`, `registration_id` (ticket items link the created Registration)
- [x] Validation: ticket item requires `ticket_type_id`; addon item requires `add_on_id`
- [x] Validation: required questions for the ticket type are answered in `responses`

### Reservation / capacity holds
- [x] Registration gains status `:reserved` and `held_until` (or reuse `:pending_payment` + `held_until` — pick one in implementation)
- [x] `CheckCapacity` change updated: count `confirmed` + held-and-unexpired against `capacity`; oversell → `:waitlisted` (free) or reject (paid presale)
- [x] Oban worker `Exhs.Events.ReservationExpiry` (Task 13): on `held_until` expiry, release the hold, cancel the order, enqueue `WaitlistPromoter`
- [x] `checkout_order` sets `held_until = now + N min`, reserves seats, returns Stripe Checkout URL

### Eligibility & validation
- [x] Extend `Exhs.Events.Validations.RegistrationAllowed`: enforce ticket-type sales window and group eligibility (`membership ∈ eligible_groups` when gated)
- [x] Free ticket order → confirm immediately, no Stripe (skip payment)
- [x] Paid ticket order → reserve, checkout, confirm on webhook
- [x] Enforce `quantity = 1` unless `ticket_type.allow_multiple` (future); one-per-member identity still applies

### Stripe wiring (Billing)
- [x] `checkout_order` builds Checkout line items from order items (ticket + add-ons), creates session on forening's connected account, stores `stripe_checkout_session_id`
- [x] Wire `checkout.session.completed` in `Exhs.Billing.Webhook` (currently a no-op): look up order by session id → `mark_order_paid` → confirm registrations → `record_payment` (`payable_type: :order`)
- [x] `charge.refunded` already handled for Payment; ensure order/registration reflect refund
- [x] Idempotency via existing Oban unique job on `stripe_event_id`

### LiveView purchase experience (leverage liveness)
- [x] Rework `ExhsWeb.PublicLive.Events.Show` purchase panel — replace the dead `href="#"` "Tilmeld" with a real multi-step flow in one LiveView: select ticket → answer questions → choose add-ons → review → pay
- [x] **Live availability**: PubSub topic per event; broadcast on reserve/confirm/release so all viewers see `seats_left` update in real time (e.g. "kun 3 tilbage")
- [x] **Live countdown**: while held, show a ticking `held_until` timer; auto-expire UI and re-enable purchase when it lapses
- [ ] **Live waitlist**: show waitlist position; update when promoted
- [x] Group-gated tickets render a presale badge and hide/disable for ineligible members with a clear reason
- [x] On free ticket: confirm in place, no redirect. On paid: redirect to Stripe, return to a confirmation LiveView
- [x] `ExhsWeb.MemberLive` — "Mine billetter" / order confirmation + receipt (Stripe-hosted), live status

### Admin UI (Task 17 surface)
- [x] Admin manages ticket types: price, capacity, sales window, eligible groups, questions, add-ons
- [x] Admin sees live sales/availability per ticket type (sold / held / left / waitlisted)

### Seeds
- [x] Extend `priv/repo/seeds.exs` (idempotent): a paid event with a normal ticket type, a **group-gated presale** ticket type (200 cap, tied to a "Graduates of 2010" group), an add-on (bus ticket), and a couple of questions (graduation year select). Pre-populate a sample paid order.

### Migrations
- [x] `mix ash.codegen --dev` iteratively, final `mix ash.codegen ticketing`

### Tests

Tenant isolation, external dep (Stripe), and LiveView interactivity all apply — test thoroughly per CLAUDE.md. Test through code interfaces (the real caller entry point), not internals. Each area below lists happy paths and the bad paths that must fail loudly. Two foreninger seeded in every isolation-sensitive test.

#### Order lifecycle (code interface)
Happy:
- [x] `create_order` → `:building`, zero total, linked to membership + event
- [x] `add_order_item` (ticket) → recomputes `total_cents` from `unit_price_cents` snapshot; item links/creates Registration
- [x] `add_order_item` (addon) → total includes add-on price
- [x] `remove_order_item` → total recomputed; removing last item leaves empty `:building` order
- [x] `cancel_order` from `:building` / `:pending_payment` → `:cancelled`, any held seats released
- [x] `get_order` returns order with items + payment loaded

Bad:
- [x] `add_order_item` to a non-`:building` order (`:paid`/`:cancelled`/`:expired`) rejected
- [x] `checkout_order` on empty order rejected
- [x] `unit_price_cents` is a snapshot — later ticket-type price change does NOT mutate an existing order total
- [x] mutate someone else's order (other membership) rejected by policy

#### OrderItem validation
Happy:
- [x] ticket item with `ticket_type_id` valid; addon item with `add_on_id` valid
- [x] required questions answered → item persists; `responses` stored keyed by question id

Bad:
- [x] ticket item missing `ticket_type_id` rejected; addon item missing `add_on_id` rejected
- [x] item with both `ticket_type_id` and `add_on_id` rejected
- [x] required question unanswered → rejected
- [x] answer for `:select` question not in `options` → rejected
- [x] answer wrong type (text for `:number`) → rejected
- [x] `quantity > 1` when `allow_multiple = false` → rejected (v1 enforces 1)

#### Group gating
- [x] ungated ticket type: any member buys (happy)
- [x] gated, member IN an eligible group: buys (happy)
- [x] gated, member NOT in any eligible group: rejected with clear reason (bad)
- [x] gated to multiple groups, member in one of them: buys (happy)
- [x] member removed from group after gating: subsequent buy rejected (bad)

#### Sales window
- [x] inside window (`sales_starts_at` < now < `sales_ends_at`): buys (happy)
- [x] before `sales_starts_at`: rejected (bad)
- [x] after `sales_ends_at`: rejected (bad)
- [x] null window falls back to event window: respects event start/end (happy + bad either side)

#### Capacity & holds
- [x] `seats_taken` counts `confirmed` + unexpired held; `seats_left = capacity - seats_taken`
- [x] nil capacity = unlimited, never blocks (happy)
- [x] hold counts toward capacity: last seat held → next buyer blocked even before payment (bad)
- [x] free oversell → `:waitlisted`; paid presale oversell → rejected
- [x] **last-seat race**: two concurrent `checkout_order` on a 1-left ticket type — exactly one wins, other rejected/waitlisted (no oversell)
- [x] expired hold no longer counts toward capacity (seat reusable)

#### Hold expiry (Oban `ReservationExpiry`)
- [x] worker on `held_until` lapse: releases hold, order → `:expired`, Registration hold cleared (happy)
- [x] expiry enqueues `WaitlistPromoter`; next waitlisted member promoted (happy)
- [x] worker is idempotent — running twice on same order no double-promote, no error
- [x] worker does NOT expire an already-`:paid` order (bad/guard)

#### Free ticket
- [x] free ticket order confirms instantly: order → `:paid` (or `:confirmed`), Registration `:confirmed`, no `held_until`
- [x] NO Stripe call made (assert stub not invoked)
- [x] NO Payment row created for a zero-total order

#### Paid ticket + Stripe (`StripeClient.Stub`)
Happy:
- [x] `checkout_order` builds line items (ticket + add-ons) on forening's connected account, stores `stripe_checkout_session_id`, sets `held_until = now + N`, order → `:pending_payment`
- [x] `checkout.session.completed` webhook → `mark_order_paid`, Registrations `:confirmed`, Payment recorded (`payable_type: :order`), `paid_at` set, hold cleared
- [x] add-on appears as a distinct Checkout line item and in order total

Bad:
- [x] webhook with bad signature rejected, no state change
- [x] same `checkout.session.completed` delivered twice → idempotent (Oban unique on `stripe_event_id`), single Payment, no double-confirm
- [x] webhook for unknown / cross-tenant session id → no-op, no crash
- [x] Stripe session creation failure (stub returns error) → order stays `:building`/`:pending_payment`, no seat permanently lost, surfaced to caller
- [x] `checkout.session.expired` / abandoned checkout → hold released on expiry (ties to Oban worker)
- [x] `charge.refunded` → Payment refunded AND order/registration reflect refund (seat freed per decided behavior)

#### One-per-member identity
- [x] duplicate ticket, same member + same ticket type → rejected (bad)
- [x] same member, DIFFERENT ticket type same event → allowed (happy)
- [x] member can re-buy after their order cancelled/expired (identity not blocked by dead order) (happy)

#### Tenant isolation
- [x] orders/ticket types/add-ons in both foreninger: each forening lists only its own
- [x] `get_order` with cross-tenant id → not found
- [x] cross-tenant `checkout_order` / `add_order_item` / `cancel_order` → rejected
- [x] cross-tenant ticket type id in `add_order_item` → rejected
- [x] webhook resolves order within correct tenant only

#### LiveView (`Phoenix.LiveViewTest`)
Happy:
- [x] purchase panel mounts on event show
- [x] full flow: select ticket → answer questions → choose add-ons → review → pay (free path confirms in place; paid path redirects to Stripe URL)
- [x] **live availability**: second process buys/reserves → first viewer's `seats_left` decrements via PubSub ("kun N tilbage")
- [x] **live countdown**: held order shows ticking `held_until` timer
- [x] **live release**: hold expires → first viewer's UI re-enables purchase, seats restored
- [ ] **live waitlist**: promotion updates waitlist position for the viewer

Bad / guard:
- [x] ineligible (gated) member: ticket disabled with reason badge, submit blocked server-side too
- [x] outside sales window: purchase disabled with reason
- [x] sold out: purchase disabled, waitlist CTA shown (free) / blocked (paid presale)
- [x] required question left blank: form re-renders with error, no order created
- [x] unauthenticated / non-member viewer: cannot purchase (redirect / disabled)

## Open decisions

- [x] **Hold duration N** — 10 min? configurable per forening or event?
- [x] **Refund → seat** — refunding a paid ticket frees the seat and auto-promotes waitlist, or admin-manual?
- [x] **Add-on without ticket** — can someone buy only a bus ticket, or must it accompany a ticket?
- [x] **Guest/multiple tickets** — future task; `allow_multiple` + per-attendee info capture deferred
- [x] **Question types** — start with text/select/number; date/checkbox later?
- [x] **VAT/moms on tickets & add-ons** — tickets may be VAT-liable unlike kontingent (see Task 8)

## Done when

- Member buys a free ticket end-to-end (instant confirm, no Stripe)
- Member buys a paid ticket + add-on end-to-end (reserve → Stripe Checkout → webhook confirm → receipt)
- A group-gated presale (e.g. 200 tickets, "Graduates of 2010") sells only to eligible members and stops at capacity
- Availability and hold countdown update **live** across concurrent viewers
- Reservations expire and release seats automatically; waitlist promotes
- Tenant isolation verified; Stripe paths tested against the stub
