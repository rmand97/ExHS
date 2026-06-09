# Use case 01 — IHS Elevmøde (annual reunion ticketing)

> A real-world use case used to validate the platform's ticketing capabilities.
> IHS is a concrete tenant; nothing here may be hard-coded to IHS. Anything
> IHS-specific (jubilee logic, graduation year, city-based transport) must be
> modeled as a reusable extension/add-on that any forening can opt into.

## Narrative

Every year IHS holds an **elevmøde** for old and new students. There is always a
fixed number of tickets.

- Everyone buying a ticket must have an **active membership** in the IHS forening.
- Each year there is a **presale for jubilarer** (5, 10, 15, 20, 25, … years
  since graduation) so they are guaranteed a ticket. When the presale ends, the
  remaining tickets go on **general sale**.
- It must be known **which year a student graduated**, so the system can validate
  whether they are a jubilæum and therefore eligible for the presale ticket.
- A buyer can add a **bus ticket** from certain cities: **one way**, **both ways**,
  or **standalone, bought after** the event ticket.
- Tickets sell **fast** — ~500 tickets in ~1 hour.
- A ticket can be **resold/transferred** to another eligible user. A jubilæum
  ticket may be transferred to a **non-jubilæum** student so it does not go to
  waste.
- A **support/check-in module**: staff mark who has **shown up**.
- Ticket holders are **eligible for event emails** — both leading up to the event
  and afterwards.
- **Visibility throughout**: a buyer can always see **what number they are in the
  queue**, **easily find their ticket**, and read its current status — without
  having to sit on the purchase page.
- An admin can **refund** a ticket, returning it to the pool (not the standard
  flow).
- After the event is created and the ticket count set, an admin can **add more
  tickets** later if more seats are found.

## Requirements → support matrix

Legend: ✅ supported · 🟡 partial · ❌ missing · ⏸️ deferred (decided out of scope for now)

| # | Requirement | Status | Where / gap |
|---|-------------|--------|-------------|
| 1 | Annual event, fixed ticket count | ✅ | `Event` + `TicketType.capacity`; `Capacity.seats_taken` enforces |
| 2 | Buyer must have active membership | ✅ | `Event.membership_required` + `RegistrationAllowed.check_membership` (`status: :active`) |
| 3 | Presale gated to jubilarer | ✅ | **Decided: handle via groups for now.** Group-gated `TicketType` + per-type sales window. Admin maintains the jubilee group ("Jubilarer 2027") each year. |
| 4 | Track graduation year (structured) | ⏸️ deferred | Out of scope for now. Captured only as a free-form `TicketTypeQuestion` answer. Revisit if manual group upkeep becomes painful. |
| 5 | Validate jubilee eligibility from year | ⏸️ deferred | Superseded by #3 group gating. Automatic `(event_year - graduation_year) rem 5` rule deferred. |
| 6 | Presale ends → general sale | ✅ | Two `TicketType`s with staggered `sales_starts_at`/`sales_ends_at` |
| 7a | Bus add-on per city/direction, limited qty | ❌ deferred | **Decided: structured transport resource** (city + direction + capacity), not flat `AddOn` rows. **Not priority 1** — build deferred. |
| 7b | Bus ticket **standalone, bought after** ticket | ❌ deferred | **Decided: must support** (any time after purchase). Blocked today (add-ons must accompany a ticket). Part of deferred transport build. |
| 7c | ~~Round-trip discount~~ | — | **Cut for now.** Each direction is its own flat-price option; no bundle discount. |
| 7d | Bus add-on refundable **separately** from ticket | ❌ deferred | No per-add-on refund path today. Part of deferred transport build. |
| 8 | High concurrency (500/hr) | ✅ | Timed holds; last-seat race tested (exactly one wins). Not load-tested at scale. |
| 9 | Resell/transfer ticket to another eligible user | ❌ | **Decided: reassign-only, no fee, private settlement; keep active-membership gate.** No transfer action exists yet (Task 27). |
| 10 | Transfer jubilee ticket to non-jubilee | ❌ | **Decided: allowed** — transfer bypasses the group gate, keeps membership gate. Depends on #9. |
| 11 | Support module — mark attendance / check-in | ❌ | **Decided: `:support` role, search + mark (QR later).** No `:support` role, no `checked_in*` field, no check-in action/UI yet (Task 28). |
| 12 | Not hard-coded for IHS; addon/extension arch | 🟡 | Core (events/tickets/add-ons/groups) is generic ✅. But jubilee logic + graduation year have **no extension seam** yet — would currently leak into core. |
| 13 | Ticket holders eligible for event emails | ❌ | Communications (Task 11) not started. No event-scoped audience = current ticket holders. |
| 14 | Admin refund → seat back in pool | ✅ | `charge.refunded` frees seat + enqueues `WaitlistPromoter` |
| 15 | Add more tickets after creation | ✅ | Admin edits `TicketType.capacity`; live availability recomputes |
| 16a | Live queue position on the buy page | ✅ | `Waitlist.standing` → "position X of Y" on `PublicLive.Events.Show`, updates via PubSub on promotion |
| 16b | Live seats-left + hold countdown | ✅ | "only N left" + ticking `held_until` timer on the buy page |
| 16c | Queue position visible **away from** the buy page | ❌ | Member "Mine tilmeldinger" (`member/registrations.ex`) shows a status badge but **not** the live queue position; `Waitlist.standing` is only wired into the public event show |
| 16d | Easily find your ticket (ticket artifact) | 🟡 | Member list + per-registration status exist; no ticket **detail page**, no QR/ticket code, no at-a-glance "your ticket" view to present at the door |
| 16e | Notified when promoted off waitlist | ❌ | Promotion updates **live only** (PubSub). No email/push if the member isn't on the page (ties to #13 emails) |

## Summary

**Supported (7):** fixed-capacity events, active-membership gate, staggered
presale→general windows, timed holds under contention, refund-to-pool, capacity
top-up, and the order/add-on aggregate as an extensible base.

**Gaps (8), grouped:**

1. **Jubilee model (#3, #4, #5).** ✅ **Resolved for now: handled via groups.**
   Admin maintains a jubilee group each year and gates the presale ticket type to
   it. Structured `graduation_year` + automatic jubilee rule are **deferred** —
   revisit only if yearly group upkeep becomes a burden.
2. **Ticket transfer / resale (#9, #10).** New action on `Registration`/`Order`
   to reassign a confirmed ticket to another eligible membership, with an
   eligibility-override path (jubilee → non-jubilee). Needs audit + new-holder
   email + payment/no-payment policy decision.
3. **Check-in / support module (#11).** `checked_in_at` + `checked_in_by` on
   `Registration`, a check-in action, and a staff LiveView (search by name/email,
   scan, mark present). Should be its own task.
4. **Standalone / post-purchase add-on (#7b).** Relax the "add-on must accompany
   a ticket" rule for buyers who already hold a confirmed ticket; allow adding an
   add-on to an existing order or a new add-on-only order gated on owning a ticket.
5. **Event emails to ticket holders (#13).** Depends on Task 11 (Communications).
   Audience = current confirmed registrations for an event; send pre- and
   post-event.
6. **Extension seam (#12).** Decide how IHS-specific concepts (jubilee, transport
   cities) attach without polluting core — e.g. a per-forening feature/profile
   extension or pluggable eligibility rules.
7. **Visibility everywhere (#16c, #16d, #16e).** The buy page is rich (live
   position, seats-left, countdown). The gap is *persistent* visibility: surface
   live queue position + hold countdown in "Mine tilmeldinger", add a ticket
   **detail page** (status, QR/code, receipt link, transport, what-to-bring) the
   member can pull up anytime, and notify on promotion when they're not watching.

## Decided

- **Jubilee** — handle via **groups** for now. Admin maintains a jubilee group
  per year and gates the presale ticket type to it. No structured graduation year.
- **Transfer / resale** — **no fee**; money is settled **privately** between
  parties. The platform only **reassigns** the ticket to the recipient.
- **Transfer eligibility** — **keep the active-membership gate** (recipient must
  be an active member), but the recipient need **not** be a jubilæum (group gate
  is bypassed on transfer — that's the whole point of transferring a jubilee
  ticket to a non-jubilee).
- **Check-in** — dedicated **`:support` membership role**. v1 is **search + mark**
  (find attendee by name/email, tap to mark present). **QR scanning later.**
- **Bus / transport add-ons** — buyable **any time after purchase** (standalone),
  not just in the original order. **Limited quantity** (per-add-on capacity).
  **Refundable separately** from the event ticket. **No round-trip discount**
  (cut for now — each direction is its own flat-price option). Modeled as a
  **structured transport resource** (city + direction + capacity), not flat
  add-ons. **NOTE: transport is not priority 1** — defer the build.

## Open questions (for review)

_None open — add-on scope settled. Transport build is deferred (not priority 1)._

## Internal audit — ticketing robustness

Beyond the IHS narrative, an audit of the ticketing internals surfaced two bugs
and three missing capabilities.

### Fixed (2026-06-09)

- ✅ **Add-on capacity was not enforced.** `AddOn.capacity` existed but nothing
  counted add-on sales against it — bus/extra add-ons could oversell freely.
  Added `Capacity.lock_add_on!` + `addon_seats_taken` and a `CheckAddonCapacity`
  change on `OrderItem.:add` (FOR UPDATE lock, counts add-on items in
  building/pending/paid orders, rejects over capacity; nil = unlimited).
- ✅ **Abandoned `:building` cart locked the buyer out.** Adding a ticket creates
  a `:pending_payment` registration immediately; the `one_per_ticket_type`
  identity (ignores only `:cancelled`) then blocked the same member from
  re-buying, and nothing ever cleaned up a cart that never reached checkout.
  Added an `:stale_building` read action + `Exhs.Events.AbandonedOrderSweeper`
  cron worker (every 15 min, cancels `:building` carts older than 30 min, which
  releases their dangling registrations).
- ✅ **Mixed-currency order.** Decided **DKK only**; added an
  `attribute_equals(:currency, "DKK")` guard on ticket-type and add-on
  create/update so a non-DKK price can never enter and desync the Stripe line
  items.

### Open — deferred to their own tasks

- ❌ **No confirmation / ticket email (#3).** Free tickets get nothing; paid get
  only Stripe's card receipt. No app-level "here's your ticket". Pairs with the
  ticket-detail page (#16d) and ties to event emails (#13 / Task 11).
- ❌ **No partial / per-item refund (#4).** `order.cancel` releases *all* holds
  and registrations; an admin can't refund a single ticket or a single add-on of
  a multi-item order. Sub-case: separate add-on refund (#7d).
- ❌ **No VAT/moms on ticket sales (#5).** Stripe line items carry `unit_amount`
  only — no `tax_rates`, no invoice. Tickets may be VAT-liable unlike kontingent
  (Task 8). Needs a rate/exemption decision before real money flows.

## Suggested follow-up tasks

- ~~Task 26 — Membership graduation year + pluggable jubilee eligibility~~ — deferred (jubilee handled via groups)
- Task 27 — Ticket transfer / resale (reassign-only, keep membership gate, bypass group gate)
- Task 28 — Event check-in / support module (`:support` role, search + mark; QR later)
- Task 29 — **(deferred, not prio 1)** Structured transport add-ons: city + direction + capacity, standalone post-purchase, separate refund (no round-trip discount)
- Task 30 — Persistent ticket visibility (queue position + ticket detail/QR in member UI, promotion notifications)
- Task 31 — Order/ticket confirmation email (#3) — free + paid, app-level
- Task 32 — Partial / per-item refund (#4, #7d) — refund one ticket or add-on, free its seat
- Task 33 — VAT/moms on tickets & add-ons (#5) — tax rates + invoice (needs rate decision)
- (Task 11) — Event-scoped email audiences (ticket holders)
