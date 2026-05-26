# Task 24 — Audit trail UI

## Goal
A user-facing activity history view showing changes made to and by a user. Viewable by the user themselves, forening admins, and superadmins.

## Prerequisites
- Task 7 (AshEvents on all resources)
- Task 14 (Design system — DaisyUI components)
- Task 16 (Member self-service UI — provides layout/nav context)

## Plan

### Member view — "My activity"
- [ ] LiveView at `/activity` (inside member live_session)
- [ ] Shows events from `Exhs.Audit.EventLog` where `user_id` is the current user
- [ ] Timeline/list layout: action name, resource type, input data summary, timestamp
- [ ] Pagination or infinite scroll
- [ ] Filter by resource type (membership, group, etc.)

### Admin view — "Member activity"
- [ ] LiveView at `/admin/members/:id/activity` (inside admin live_session)
- [ ] Admin can view any member's activity history within their forening
- [ ] Shows both changes made BY the member and changes made TO the member's records
- [ ] Same timeline component as member view

### Superadmin view — "Global activity"
- [ ] Superadmin can view activity across all foreninger
- [ ] Filter by forening, user, resource type, date range

### Shared components
- [ ] `AuditTimeline` component — renders a list of events as a timeline
- [ ] `EventDetail` component — renders event data and changed_attributes
- [ ] Action name displayed as human-readable label (e.g., `:set_role` → "Changed role")

### Code interfaces
- [ ] `Exhs.Audit` code interfaces for querying EventLog by actor, resource, record_id
- [ ] Scoped reads with filters on `user_id`, `resource`, `record_id`

### Policies
- [ ] User can read events where they are the actor or the subject
- [ ] Admin/board can read all events in their forening (filter by resource records' tenant)
- [ ] Superadmin can read all events globally

## Done when
- A member can see their own activity history
- An admin can see any member's activity in their forening
- A superadmin can see activity across foreninger
- Timeline is paginated and filterable
