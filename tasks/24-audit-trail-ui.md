# Task 24 — Audit trail UI

## Goal
A user-facing activity history view showing changes made to and by a user. Viewable by the user themselves, forening admins, and superadmins.

## Prerequisites
- Task 7 (AshEvents on all resources)
- Task 14 (Design system — DaisyUI components)
- Task 16 (Member self-service UI — provides layout/nav context)

## Plan

### Member view — "My activity"
- [x] LiveView at `/activity` (inside member live_session)
- [x] Shows events from `Exhs.Audit.EventLog` where `user_id` is the current user
- [x] Timeline/list layout: action name, resource type, input data summary, timestamp
- [x] Pagination or infinite scroll
- [x] Filter by resource type (membership, group, etc.)

### Admin view — "Member activity"
- [ ] LiveView at `/admin/members/:id/activity` (inside admin live_session)
- [ ] Admin can view any member's activity history within their forening
- [ ] Shows both changes made BY the member and changes made TO the member's records
- [ ] Same timeline component as member view

### Superadmin view — "Global activity"
- [ ] Superadmin can view activity across all foreninger
- [ ] Filter by forening, user, resource type, date range

### Shared components
- [x] `AuditTimeline` component — renders a list of events as a timeline
- [x] `EventDetail` component — renders event data and changed_attributes
- [x] Action name displayed as human-readable label (e.g., `:set_role` → "Changed role")

### Code interfaces
- [x] `Exhs.Audit` code interfaces for querying EventLog by actor, resource, record_id
- [x] Scoped reads with filters on `user_id`, `resource`, `record_id`

### Policies
- [x] User can read events where they are the actor or the subject
- [ ] Admin/board can read all events in their forening (filter by resource records' tenant)
- [x] Superadmin can read all events globally

## Testing plan

### Backend tests (`test/exhs/audit_ui_test.exs`)

#### Code interface tests
- [x] `list_my_activity/1` returns events where `user_id` matches actor
- [x] `list_my_activity/1` returns empty list when user has no events
- [x] `list_my_activity/1` does NOT return events from other users (even in same forening)

#### Policy tests
- [x] User can read events where they are the actor (`user_id`)
- [x] User CANNOT read events where another user is the actor
- [x] Superadmin can read all events globally (bypass)
- [x] Unauthenticated actor (`nil`) is rejected (requires actor)

#### Tenant isolation (critical)
- [x] User in forening A makes changes → events appear in their activity
- [x] User in forening B makes changes → those events do NOT appear in user A's activity
- [x] User who is a member of BOTH foreninger sees events from both (scoped to their user_id only)
- [x] Admin of forening A cannot see events from forening B's members
- [x] Events created with `authorize?: false` (seeds, system) have `user_id: nil` and do not leak into any user's activity view

### Frontend tests (`test/exhs_web/live/member/activity_test.exs`)

#### Mount & authentication
- [x] Unauthenticated user redirected to `/sign-in`
- [x] Authenticated user sees activity page with header

#### Activity display
- [x] Events from user's actions across foreninger appear in timeline
- [x] Empty state shown when user has no activity
- [x] Each event shows: action label, resource type, timestamp
- [x] Events are ordered most-recent-first (via action sort)

#### Tenant isolation (LiveView)
- [x] User only sees their own events — other users' events do not appear
- [x] User in two foreninger sees activity from both, but not from other users in those foreninger
- [x] Admin making changes in forening A → those events visible in admin's own activity, not in regular member's activity

#### Filtering
- [x] Resource type filter restricts visible events
- [x] Pagination works (next/prev pages)

## Done when
- A member can see their own activity history
- An admin can see any member's activity in their forening
- A superadmin can see activity across foreninger
- Timeline is paginated and filterable
