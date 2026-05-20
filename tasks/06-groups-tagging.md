# Task 6 — Groups & tagging

## Goal
Admin-defined collections (groups/tags) for segmenting members. Used by newsletters (Task 11), events (Task 9), and reporting.

## Prerequisites
- Task 4 (Membership exists), Task 5 (admin policies in place)

## Plan

### Group resource
- [x] `Exhs.Organizations.Group` at `lib/exhs/organizations/group.ex`
- [x] Multitenancy: `:attribute` on `forening_id`
- [x] Attributes: `id`, `name` (string, unique within tenant), `description`, `color` (string, hex), timestamps
- [x] Identity: unique name per forening

### MemberGroup join resource
- [x] `Exhs.Organizations.MemberGroup` at `lib/exhs/organizations/member_group.ex`
- [x] Multitenancy: `:attribute` on `forening_id`
- [x] `belongs_to :membership`, `belongs_to :group`
- [x] Identity: unique `(membership_id, group_id, forening_id)` per tenant
- [x] Code interface: `add_member_to_group`, `remove_member_from_group`

### Membership relationships
- [x] `many_to_many :groups, Group, through: MemberGroup`

### Domain code interface
- [x] `Exhs.Organizations.list_groups/1`
- [x] `Exhs.Organizations.create_group/2`, `update_group/3`, `destroy_group/2`
- [x] `Exhs.Organizations.add_member_to_group/2`, `remove_member_from_group/2`

### Policies
- [x] Read groups: any active member of forening
- [x] CRUD groups: admin only
- [x] Assign/remove: admin only

### Tests (17 tests)
- [x] Admin CRUD (create, update, destroy)
- [x] Unique group name per forening (not globally)
- [x] Same name allowed in different foreninger
- [x] Color validation (hex format)
- [x] Can't add same member to same group twice
- [x] Member's groups loadable via `load: [:groups]`
- [x] Policy tests (member can't create/update/destroy/assign, cross-tenant isolation)

## Decided
- **Tags vs groups** — single `Group` resource is enough. No separate Tag model.
- **Group types** — not needed now. Simple name/description/color. Can add a type enum later if needed.

## Done when
- Admin can CRUD groups and assign members ✓
- Members can see which groups they're in ✓
- Group segmentation usable from newsletter segments (Task 11)
