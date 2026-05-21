# Task 24 — Audit trail UI

## Goal
A user-facing activity history view showing changes made to and by a user. Viewable by the user themselves, forening admins, and superadmins.

## Prerequisites
- Task 7 (AshPaperTrail on Organizations resources)
- Task 14 (Design system — DaisyUI components)
- Task 16 (Member self-service UI — provides layout/nav context)

## Plan

### Member view — "My activity"
- [ ] LiveView at `/activity` (inside member live_session)
- [ ] Shows version records where actor is the current user, scoped to current forening
- [ ] Timeline/list layout: action name, resource type, changed fields, timestamp
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
- [ ] `AuditTimeline` component — renders a list of version records as a timeline
- [ ] `VersionDiff` component — renders changed fields (key → new value for changes_only mode)
- [ ] Action name displayed as human-readable label (e.g., `:set_role` → "Changed role")

### Code interfaces
- [ ] `Exhs.Organizations.list_versions_for_actor/2` — versions where user_id matches
- [ ] `Exhs.Organizations.list_versions_for_resource/3` — versions for a specific resource instance
- [ ] Both scoped to tenant

### Policies
- [ ] User can read version records where they are the actor or the subject
- [ ] Admin/board can read all version records in their forening
- [ ] Superadmin can read all version records globally

## Done when
- A member can see their own activity history
- An admin can see any member's activity in their forening
- A superadmin can see activity across foreninger
- Timeline is paginated and filterable
