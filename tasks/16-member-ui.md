# Task 16 — Member self-service UI

## Goal
Logged-in members manage their profile, see payment history, register for events, cancel/restart subscription, and buy merch — all scoped to whichever forening's subdomain they're on.

## Prerequisites
- Task 3 (auth), Task 4 (Membership), Task 8 (Billing), Task 9 (Events), Task 14 (design system)

## Plan

### Routing & auth
- [ ] Member scope under forening subdomain, requires authenticated user + Membership in that forening
- [ ] If user has no Membership in that forening → redirect to "Join" page

### LiveViews
- [ ] `MemberLive.Dashboard` — overview (membership status, upcoming events I'm registered for, recent payments)
- [ ] `MemberLive.Profile` — edit name, address, phone, upload avatar
- [ ] `MemberLive.Membership` — current status, kontingent details, cancel / restart subscription, leave forening
- [ ] `MemberLive.Payments` — list of all payments (kontingent, tickets, merch), Stripe-hosted receipt links
- [ ] `MemberLive.Events.Index` — events I can register for
- [ ] `MemberLive.Events.MyRegistrations` — my registrations and waitlist positions
- [ ] `MemberLive.Shop.MyOrders` — my orders + fulfillment status

### Forms
- [ ] All forms use `AshPhoenix.Form` + code interface `form_to_*` helpers
- [ ] Avatar upload uses LiveView external uploads → Minio (Task 12)

### Subscription self-service
- [ ] Cancel button → confirms → calls `cancel_kontingent_subscription`
- [ ] Restart button (for inactive members) → checkout session
- [ ] Show "next renewal" date, "cancels at" date

### Multi-forening UX
- [ ] If user has memberships in multiple foreninger, surface a "switch forening" element pointing to other subdomains
- [ ] No cross-forening data leakage — each subdomain shows only its forening's data

### Tests
- [ ] Cannot access member area without active session
- [ ] Cannot access forening B's member area while only being a member of A
- [ ] Profile updates persist; avatar upload roundtrips

## Open decisions
- [ ] **Notification preferences** — email-only or in-app too? (toggle per category)
- [ ] **Account deletion** — self-serve via UI (triggers GDPR flow Task 18), or admin-only?
- [ ] **Inactive member experience** — view-only of past stuff, or strip down to just "reactivate"?

## Done when
- Member can do every self-service flow in plan end-to-end
- Tenant isolation is verified
- Subscription cancel/restart works through Stripe webhooks
