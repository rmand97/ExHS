# Task 5 — Roles & policies

## Goal
Authorization rules covering superadmin / admin / board / active member / inactive member, applied consistently to every resource.

## Prerequisites
- Task 4 (Membership and roles exist)

## Plan

### Policy primitives
- [ ] Custom check: `Exhs.Checks.Superadmin` — `actor.is_superadmin == true`
- [ ] Custom check: `Exhs.Checks.MembershipRole` — actor has a Membership in current tenant with role in `[:admin]` (parameterizable)
- [ ] Custom check: `Exhs.Checks.MembershipStatus` — actor's Membership in tenant is `:active`
- [ ] Filter check: `Exhs.Checks.SelfMembership` — limits records to actor's own Membership

### Resource policies — Forening
- [ ] Bypass: superadmin → always allow
- [ ] Read: any authenticated user who has a Membership in the forening
- [ ] Create / archive: superadmin only
- [ ] Update branding / kontingent settings: forening admin

### Resource policies — Membership
- [ ] Bypass: superadmin
- [ ] Read: forening admin/board sees all; member sees own only
- [ ] Create (invite): forening admin
- [ ] Update role: forening admin only (cannot demote/remove last admin — validation)
- [ ] Update status manually: forening admin (audit-logged escape hatch)
- [ ] Destroy: forening admin (or GDPR flow in Task 18)

### Resource policies — User
- [ ] Read/update own profile only (except superadmin)
- [ ] No cross-forening leakage of profile data

### Field policies
- [ ] User: sensitive fields (`hashed_password`) never readable
- [ ] Membership: notes field (if added) admin-only

### Policy doc
- [ ] Write `docs/policies.md` (or section in `AGENTS.md`) summarizing role matrix → resources
- [ ] Table: role × resource × action → allow/deny

### Tests
- [ ] Each policy has a positive and negative test case
- [ ] `Ash.can?/3` checks used in code-interface-driven tests
- [ ] Test that non-superadmin cannot create foreninger
- [ ] Test that admin of forening A cannot read forening B's members

## Open decisions
- [ ] **Board vs admin** — exact split of permissions; right now plan says board can view financials/reports/dashboard. Confirm board cannot edit anything
- [ ] **Self-invite vs admin-invite** — can users request to join a forening, or only admins invite?
- [ ] **Last-admin safeguard** — strict (block destroy) or warn-then-allow?

## Done when
- All resources from Tasks 3–4 have policies
- Role matrix doc exists and matches policies
- CI runs the policy tests; can?-checks used in admin UI (Task 17) for conditional rendering
