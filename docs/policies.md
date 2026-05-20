# Authorization policy matrix

## Roles

| Role | Scope | Description |
|------|-------|-------------|
| **Superadmin** | Global | `user.is_superadmin == true`. Bypasses all policies. |
| **Admin** | Per-forening | Membership with `role: :admin`. Full CRUD on forening resources. |
| **Board** | Per-forening | Membership with `role: :board`. Read-only access to forening resources. |
| **Member** | Per-forening | Membership with `role: :member`. Can read own membership. |

A user can hold different roles in different foreninger simultaneously.

## Policy checks

| Check module | Type | Purpose |
|---|---|---|
| `Exhs.Checks.Superadmin` | SimpleCheck | `actor.is_superadmin == true` |
| `Exhs.Checks.HasMembershipRole` | SimpleCheck | Actor has membership in current tenant with role in given list |
| `Exhs.Checks.ActiveMember` | SimpleCheck | Actor has active membership in current tenant |

## User resource

| Action | Superadmin | Self | Other user | Unauthenticated |
|--------|-----------|------|------------|-----------------|
| Read | Allow | Allow | Deny | Deny |
| Update profile | Allow | Allow | Deny | Deny |
| Change password | Allow | Allow | Deny | Deny |
| Register | N/A (auth) | N/A (auth) | N/A (auth) | Allow |
| Sign in | N/A (auth) | N/A (auth) | N/A (auth) | Allow |

`hashed_password` is non-public and `sensitive? true` -- never exposed in reads.

## Forening resource

| Action | Superadmin | Admin | Board/Member | Unauthenticated |
|--------|-----------|-------|--------------|-----------------|
| Read | Allow | Allow | Allow | Deny |
| Create | Allow | Deny | Deny | Deny |
| Update | Allow | Allow | Deny | Deny |
| Archive | Allow | Deny | Deny | Deny |

## Membership resource (tenant-scoped to forening)

| Action | Superadmin | Admin | Board | Member (own) | Other member | Unauthenticated |
|--------|-----------|-------|-------|-------------|--------------|-----------------|
| Read | Allow | Allow | Allow | Allow (own) | Deny | Deny |
| Join | Allow | N/A | N/A | N/A | N/A | Deny |
| Invite | Allow | Allow | Deny | Deny | Deny | Deny |
| Activate | Allow | Allow | Deny | Deny | Deny | Deny |
| Deactivate | Allow | Allow | Deny | Deny | Deny | Deny |
| Set role | Allow | Allow | Deny | Deny | Deny | Deny |
| Leave | Allow | N/A | N/A | Allow (own) | Deny | Deny |

## Cross-tenant isolation

Multitenancy uses attribute strategy on `forening_id`. An admin of forening A has no access to forening B's memberships. The tenant is always passed via `Exhs.Scope` and enforced at the Ash query level.

## Last-admin safeguard

The last admin of a forening cannot be demoted (`set_role`) or removed (`leave`). Custom validations `NotLastAdmin` and `NotLastAdminDestroy` enforce this.
