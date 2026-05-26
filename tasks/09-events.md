# Task 9 — Events

## Goal
Foreninger create events, members register, tickets can be free or paid, capacity + waitlist enforced. Events can be marked `membership_required: false` to allow inactive members to register.

## Prerequisites
- Task 4 (Membership), Task 5 (policies), Task 8 (Payments for paid tickets)

## Plan

### Events domain
- [x] `Exhs.Events` domain module
- [x] Register in `ash_domains`

### Event resource
- [x] `Exhs.Events.Event` at `lib/exhs/events/event.ex`
- [x] Multitenancy: `:attribute` on `forening_id`
- [x] Attributes: `id`, `title`, `description` (text), `location`, `starts_at`, `ends_at`, `published` (bool), `membership_required` (bool, default true), `cover_image_url`, `registration_opens_at`, `registration_closes_at`, timestamps
- [x] Code interface: `publish`, `unpublish`, `list_upcoming`

### TicketType resource
- [x] `Exhs.Events.TicketType` at `lib/exhs/events/ticket_type.ex`
- [x] Multitenancy: `:attribute` on `forening_id`
- [x] `belongs_to :event`
- [x] Attributes: `name`, `price_cents` (0 = free), `currency`, `capacity` (nullable = unlimited), `description`, timestamps
- [x] Identity: unique name per event

### Registration resource
- [x] `Exhs.Events.Registration` at `lib/exhs/events/registration.ex`
- [x] Multitenancy: `:attribute` on `forening_id`
- [x] `belongs_to :membership`, `belongs_to :ticket_type`
- [x] Attributes: `status` (atom: `:confirmed | :waitlisted | :cancelled | :pending_payment`), `registered_at`, `cancelled_at`, timestamps
- [ ] `belongs_to :payment` (nullable for free tickets) — deferred to paid ticket wiring
- [x] Identity: unique `(membership_id, ticket_type_id)` per tenant
- [x] Change module `CheckCapacity` — capacity check in before_action, sets status to confirmed or waitlisted

### Validations
- [x] Validation: `RegistrationAllowed` — checks published, registration window, and membership status
- [x] When `event.membership_required == false`, inactive members can register
- [x] When `event.membership_required == true` (default), active membership required

### Code interface
- [x] `Exhs.Events.register_for_event` — free tickets get immediate confirm/waitlist
- [x] `Exhs.Events.cancel_registration` — sets status + cancelled_at
- [x] Waitlist promotion worker on cancellation (Task 13)
- [x] `Exhs.Events.list_registrations` (admin)

### Policies
- [x] Event read (published): any authenticated member
- [x] Event CRUD: admin
- [x] Registration: create = self or admin, read own + admin/board sees all, cancel own or admin

### Capacity + waitlist
- [x] Capacity enforced via count in before_action hook
- [x] Waitlist FIFO promotion handled by Oban worker on cancellations (Task 13)

### Tests
- [x] Cannot register without active membership (membership-required event)
- [x] CAN register without active membership (open event)
- [x] Capacity limit honored — second registrant gets waitlisted
- [x] Cancellation sets status + timestamp
- [x] Duplicate registration rejected
- [x] Cannot register for unpublished event
- [x] Admin creates and publishes event
- [x] Non-admin cannot create events
- [ ] Concurrent registration simulation (load test, deferred)
- [ ] Paid ticket creates Payment + Registration linked correctly (deferred to one-time charge wiring)

## Decided

- **`membership_required` boolean on Event** — default `true`. When `false`, any forening member (even inactive) can register. This resolves the "external attendees" open question: non-members still can't register (need a Membership record due to multitenancy), but lapsed members can attend open events.
- **Paid ticket flow deferred** — `Registration` has `:pending_payment` status but Stripe checkout wiring for one-time charges is not yet connected. Free tickets work end-to-end.

## Open decisions
- [ ] **Refund policy on cancellation** — automatic refund, partial, or none?
- [ ] **Recurring events** — series support in v1 or later?
- [ ] **Calendar export** — .ics files for registered members?

## Done when
- Admin creates event with multiple ticket types
- Active members can register; inactive get blocked on membership-required events
- Inactive members can register for open events (`membership_required: false`)
- Capacity & waitlist work
- Paid tickets flow through Stripe → Payment → Registration confirmed (deferred)
