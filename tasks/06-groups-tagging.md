# Task 6 — Groups & tagging

## Goal
Admin-defined collections (groups/tags) for segmenting members. Used by newsletters (Task 11), events (Task 9), and reporting.

## Prerequisites
- Task 4 (Membership exists), Task 5 (admin policies in place)

## Plan

### Group resource
- [ ] `Exhs.Organizations.Group` at `lib/exhs/organizations/group.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] Attributes: `id`, `name` (string, unique within tenant), `description`, `color` (string, hex), timestamps
- [ ] Identity: unique name per forening

### MemberGroup join resource
- [ ] `Exhs.Organizations.MemberGroup` at `lib/exhs/organizations/member_group.ex`
- [ ] Multitenancy: `:attribute` on `forening_id`
- [ ] `belongs_to :membership`, `belongs_to :group`, both primary key + non-null
- [ ] Identity: unique `(membership_id, group_id)` per tenant
- [ ] Code interface: `add`, `remove`

### Membership relationships
- [ ] `many_to_many :groups, Group, through: MemberGroup`

### Domain code interface
- [ ] `Exhs.Organizations.list_groups/1`
- [ ] `Exhs.Organizations.assign_member_to_groups/3` (bulk)
- [ ] `Exhs.Organizations.remove_member_from_groups/3`

### Policies
- [ ] Read groups: any member of forening
- [ ] CRUD groups: admin only
- [ ] Assign/remove: admin only

### Tests
- [ ] Unique group name per forening (not globally)
- [ ] Can't add same member to same group twice
- [ ] Member's groups loadable via `load: [:groups]`

## Open decisions
- [ ] **Tags vs groups** — original plan mentioned both. Treat tags as just one-off groups, or model `Tag` separately? Recommendation: single `Group` resource is enough
- [ ] **Group types** — should groups have a "type" (e.g., committee, cohort, interest) for richer segmentation later?

## Done when
- Admin can CRUD groups and assign members
- Members can see which groups they're in
- Group segmentation usable from newsletter segments (Task 11)
