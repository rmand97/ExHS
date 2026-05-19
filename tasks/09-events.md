# Task 9 — Events

## Goal
Foreninger create events, members register (active membership required), tickets can be free or paid, capacity + waitlist enforced.

## Prerequisites
- Task 4 (Membership), Task 5 (policies), Task 8 (Payments for paid tickets)

## Plan

### Events domain
- [ ] `Exhs.Events` domain module
- [ ] Register in `ash_domains`

### Event resource
- [ ] `Exhs.Events.Event` at `lib/exhs/events/event.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] Attributes: `id`, `title`, `description` (text), `location`, `starts_at`, `ends_at`, `published` (bool), `cover_image_url`, `registration_opens_at`, `registration_closes_at`, timestamps
- [ ] Code interface: `publish`, `unpublish`, `list_upcoming`

### TicketType resource
- [ ] `Exhs.Events.TicketType` at `lib/exhs/events/ticket_type.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] `belongs_to :event`
- [ ] Attributes: `name`, `price_cents` (0 = free), `currency`, `capacity` (nullable = unlimited), `description`, timestamps
- [ ] Identity: unique name per event

### Registration resource
- [ ] `Exhs.Events.Registration` at `lib/exhs/events/registration.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] `belongs_to :membership`, `belongs_to :ticket_type`
- [ ] Attributes: `status` (atom: `:confirmed | :waitlisted | :cancelled`), `registered_at`, `cancelled_at`, timestamps
- [ ] `belongs_to :payment` (nullable for free tickets)
- [ ] Identity: unique `(membership_id, ticket_type_id)` per tenant (one registration per ticket type per member)
- [ ] Change module `CheckCapacity` — atomic capacity check, sets status to confirmed or waitlisted

### Validations
- [ ] Validation: membership status must be `:active` at registration time
- [ ] Validation: registration window open
- [ ] Validation: event published

### Code interface
- [ ] `Exhs.Events.register_for_event/3` — handles paid (creates checkout session, registration pending until Payment succeeds) and free (immediate confirm)
- [ ] `Exhs.Events.cancel_registration/2` — also triggers waitlist promotion worker (Task 13)
- [ ] `Exhs.Events.list_registrations_for_event/2` (admin)

### Policies
- [ ] Event read (published): public on forening page
- [ ] Event CRUD: admin
- [ ] Registration: create = self (with active membership), read own + admin sees all, cancel own

### Capacity + waitlist
- [ ] Capacity enforced atomically (DB-level count or `for update` pattern)
- [ ] Waitlist FIFO; promotion handled by Oban worker on cancellations (Task 13)

### Tests
- [ ] Cannot register without active membership
- [ ] Capacity limit honored under concurrent registration (simulate)
- [ ] Cancellation promotes first waitlisted registration
- [ ] Paid ticket creates Payment + Registration linked correctly

## Open decisions
- [ ] **External attendees** — can non-members buy tickets? Original plan says no. Confirm.
- [ ] **Refund policy on cancellation** — automatic refund, partial, or none?
- [ ] **Recurring events** — series support in v1 or later?
- [ ] **Calendar export** — .ics files for registered members?

## Done when
- Admin creates event with multiple ticket types
- Active members can register; inactive get blocked
- Capacity & waitlist work under load test
- Paid tickets flow through Stripe → Payment → Registration confirmed
