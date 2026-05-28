# Task 16 — Member self-service UI

## Goal
Logged-in members manage their profile, see payment history, register for events, cancel/restart subscription, and buy merch — all scoped to whichever forening's subdomain they're on.

## Prerequisites
- Task 3 (auth), Task 4 (Membership), Task 8 (Billing), Task 9 (Events), Task 14 (design system)

## Plan

### Routing & auth
- [x] Member scope on main domain, requires authenticated user
- [ ] If user has no Membership in that forening → redirect to "Join" page

### LiveViews
- [x] `MemberLive.Dashboard` — cross-forening membership overview with LiveFilter (search, role, status filters, pagination)
- [x] `MemberLive.Profile` — edit name, address, phone (AshPhoenix.Form)
- [x] `MemberLive.MembershipShow` — membership detail with kontingent/subscription status, leave forening
- [x] `MemberLive.Payments` — cross-forening payment history with LiveFilter (search, status, type filters)
- [ ] `MemberLive.Events.Index` — events I can register for
- [x] `MemberLive.Registrations` — my registrations across foreninger with LiveFilter
- [ ] `MemberLive.Shop.MyOrders` — deferred (Task 10)

### Forms
- [x] Profile form uses `AshPhoenix.Form` + `form_to_update_profile`
- [ ] Avatar upload uses LiveView external uploads → Minio (Task 12)

### Subscription self-service
- [x] Show subscription status, period dates, cancel_at_period_end flag
- [ ] Cancel button → confirms → calls Stripe `cancel_kontingent_subscription` (needs live Stripe)
- [ ] Restart button (for inactive members) → checkout session (needs live Stripe)

### Multi-forening UX
- [x] Dashboard shows all memberships across foreninger with filter/pagination
- [x] No cross-forening data leakage — `my_memberships` and `my_registrations` actions filter by actor

### Ash layer
- [x] `Membership.my_memberships` — `multitenancy :allow_global`, filter by actor
- [x] `Registration.my_registrations` — `multitenancy :bypass_all`, filter by actor through membership
- [x] `Subscription.my_subscriptions` — `multitenancy :bypass_all`, filter by actor through membership
- [x] `Payment.my_payments` — `multitenancy :bypass_all`, argument-based filter by membership IDs, `bypass` policy
- [x] `Layouts.member` — dedicated member layout with Dashboard/Events/Profil/Betalinger nav

### Tests
LiveView tests via `Phoenix.LiveViewTest` — at least mount + the main interaction per LiveView.

- [x] Unauthenticated request to member area redirects to sign-in (3 tests)
- [x] Dashboard shows memberships across foreninger, hides other users' data (3 tests)
- [x] Profile update form submits and persists (2 tests)
- [x] Registrations shows cross-forening data, hides other users' (3 tests)
- [x] Membership show: details, subscription info, non-owned redirect (4 tests)
- [x] Payments: history, empty state, auth redirect (3 tests)
- [x] Ash action tests: memberships, registrations, subscriptions, payments (12 tests)
- [ ] Notification-preferences toggles save and reload correctly — deferred
- [ ] Anything triggering a real-time update (LV `assign`/`stream` after PubSub) is exercised — deferred

## Open decisions
- [ ] **Notification preferences** — email-only or in-app too? (toggle per category)
- [ ] **Account deletion** — self-serve via UI (triggers GDPR flow Task 18), or admin-only?
- [ ] **Inactive member experience** — view-only of past stuff, or strip down to just "reactivate"?

## Done when
- Member can do every self-service flow in plan end-to-end
- Tenant isolation is verified
- Subscription cancel/restart works through Stripe webhooks
