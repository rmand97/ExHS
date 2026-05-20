# Task 4 — Organizations core & multitenancy

## Goal
The `Forening` (tenant), `Membership` (User ↔ Forening bridge), and the attribute-based multitenancy plumbing that scopes every later resource.

## Prerequisites
- Task 3 (User exists)

## Plan

### Organizations domain
- [x] Create `Exhs.Organizations` domain module (`lib/exhs/organizations.ex`)
- [x] Register in `config :exhs, ash_domains`

### Forening resource
- [x] `Exhs.Organizations.Forening` at `lib/exhs/organizations/forening.ex`
- [x] Postgres table `foreninger`
- [x] Attributes: `id`, `name`, `slug` (unique), `subdomain` (unique), `branding` (map: logo_url, primary_color, etc.), `kontingent_amount_cents`, `kontingent_currency` (default `DKK`), `kontingent_stripe_price_id`, `active` (boolean), timestamps
- [x] Identities: `unique_slug`, `unique_subdomain`
- [x] No multitenancy (it IS the tenant)
- [x] Actions: `create` (superadmin-only — full policies in Task 5), `update`, `read`, `archive`

### Membership resource
- [x] `Exhs.Organizations.Membership` at `lib/exhs/organizations/membership.ex`
- [x] Multitenancy: `strategy :attribute, attribute: :forening_id`
- [x] Attributes: `id`, `role` (atom: `:admin | :board | :member`), `status` (atom: `:active | :inactive`), `joined_at`, `activated_at`, `deactivated_at`, timestamps
- [x] `belongs_to :user, Exhs.Accounts.User`
- [x] `belongs_to :forening, Exhs.Organizations.Forening` (provides `forening_id`)
- [x] Identity: `unique_user_per_forening` on `[:user_id, :forening_id]` (tenant-aware)
- [x] Code interface: `invite`, `activate`, `deactivate`, `set_role`, `leave`

### Ash.Scope plumbing
- [x] Define `Exhs.Scope` struct holding `actor` and `tenant` (forening_id)
- [x] Helper for building scope from `conn`/`socket` based on subdomain + current user
- [x] Document scope-passing convention in `CLAUDE.md`

### Subdomain routing
- [x] Plug that resolves subdomain → forening, assigns to conn
- [x] LiveView mount hook that does the same for sockets
- [x] 404 / not-found page when subdomain doesn't match an active forening
- [x] Reserved subdomains list (`www`, `app`, `admin`, `api`, etc.)
- [x] Dev-mode handling for `localhost` (path-based fallback? `*.lvh.me`?)

### Superadmin global routes
- [x] Decide superadmin lives on dedicated subdomain (`admin.exhs.dk`)
- [ ] Routes scaffold (UI in Task 17 / a separate superadmin section)

### Migrations
- [x] Run `mix ash.codegen --dev` iteratively, then a final named migration

### Tests
- [x] Create forening
- [x] Membership uniqueness per forening (same user can join multiple foreninger)
- [x] Tenant attribute is set automatically when scope provided
- [x] Subdomain plug resolves correctly

## Decided
- **Subdomain dev handling** — `*.lvh.me` in dev/test, configured via `config :exhs, :base_host`
- **Superadmin** — dedicated subdomain `admin.exhs.dk`, reserved in the plug

## Open decisions
- [ ] **Custom domains** — do foreninger get custom domains in v1, or only `*.exhs.dk`?
- [ ] **Forening archival** — soft-delete or hard-delete? GDPR implications (Task 18)

## Done when
- Two foreninger can coexist with overlapping members
- Tenant attribute auto-populates from scope on all Membership actions
- Subdomain resolution works end-to-end (dev + test)
- Code interface used everywhere; no raw `Ash.` calls in web modules
