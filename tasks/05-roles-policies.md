# Task 5 — Roles & policies

## Goal
Authorization rules covering superadmin / admin / board / active member / inactive member, applied consistently to every resource.

## Prerequisites
- Task 4 (Membership and roles exist)

## Plan

### Policy primitives
- [x] Custom check: `Exhs.Checks.Superadmin` — `actor.is_superadmin == true`
- [x] Custom check: `Exhs.Checks.HasMembershipRole` — actor has a Membership in current tenant with role in `[:admin]` (parameterizable)
- [x] Custom check: `Exhs.Checks.ActiveMember` — actor's Membership in tenant is `:active`
- [x] Self-membership access via inline `expr(user_id == ^actor(:id))` in policies (no separate FilterCheck needed)

### Resource policies — Forening
- [x] Bypass: superadmin → always allow
- [x] Read: any authenticated user
- [x] Create / archive: superadmin only
- [x] Update branding / kontingent settings: forening admin

### Resource policies — Membership
- [x] Bypass: superadmin
- [x] Read: forening admin/board sees all; member sees own only
- [x] Create (invite): forening admin
- [x] Join: any authenticated user (self-service, no approval)
- [x] Update role: forening admin only (cannot demote/remove last admin — validation)
- [x] Activate/deactivate: forening admin
- [x] Leave (destroy): own membership only

### Resource policies — User
- [x] Read/update own profile only (except superadmin)
- [x] No cross-forening leakage of profile data

### Field policies
- [x] User: `hashed_password` is non-public and `sensitive? true` — never exposed (field policy not needed for non-public attributes)

### Policy doc
- [x] `docs/policies.md` — role matrix with role × resource × action table

### Tests
- [x] Each policy has positive and negative test cases (44 policy tests)
- [x] Tests use code interfaces with `scope:` / `actor:` / `tenant:` options
- [x] Test that non-superadmin cannot create foreninger
- [x] Test that admin of forening A cannot read forening B's members
- [x] Cross-tenant isolation tests (7 tests)
- [x] Last-admin safeguard tests (4 tests)

## Decided
- **Board vs admin** — board is view-only (can read everything admin can, but cannot edit). Admin has full CRUD. A user can hold both roles simultaneously.
- **Self-invite vs admin-invite** — open joining, no approval needed. Users can join any forening directly.
- **Last-admin safeguard** — strict block. Cannot demote or remove the last admin of a forening.
- **Field policies** — `hashed_password` is already non-public and sensitive; Ash field policies only apply to public attributes, so no field_policy block needed.

## Done when
- All resources from Tasks 3–4 have policies ✓
- Role matrix doc exists and matches policies ✓
- CI runs the policy tests; can?-checks used in admin UI (Task 17) for conditional rendering
