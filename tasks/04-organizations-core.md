# Task 4 — Organizations core & multitenancy

## Goal
The `Forening` (tenant), `Membership` (User ↔ Forening bridge), and the attribute-based multitenancy plumbing that scopes every later resource.

## Prerequisites
- Task 3 (User exists)

## Plan

### Organizations domain
- [ ] Create `Exhs.Organizations` domain module (`lib/exhs/organizations.ex`)
- [ ] Register in `config :exhs, ash_domains`

### Forening resource
- [ ] `Exhs.Organizations.Forening` at `lib/exhs/organizations/forening.ex`
- [ ] Postgres table `foreninger`
- [ ] Attributes: `id`, `name`, `slug` (unique), `subdomain` (unique), `branding` (map: logo_url, primary_color, etc.), `kontingent_amount_cents`, `kontingent_currency` (default `DKK`), `kontingent_stripe_price_id`, `active` (boolean), timestamps
- [ ] Identities: `unique_slug`, `unique_subdomain`
- [ ] No multitenancy (it IS the tenant)
- [ ] Actions: `create` (superadmin-only — full policies in Task 5), `update`, `read`, `archive`

### Membership resource
- [ ] `Exhs.Organizations.Membership` at `lib/exhs/organizations/membership.ex`
- [ ] Multitenancy: `strategy :attribute, attribute: :forening_id`
- [ ] Attributes: `id`, `role` (atom: `:admin | :board | :member`), `status` (atom: `:active | :inactive`), `joined_at`, `activated_at`, `deactivated_at`, timestamps
- [ ] `belongs_to :user, Exhs.Accounts.User`
- [ ] `belongs_to :forening, Exhs.Organizations.Forening` (provides `forening_id`)
- [ ] Identity: `unique_user_per_forening` on `[:user_id, :forening_id]` (tenant-aware)
- [ ] Code interface: `invite`, `activate`, `deactivate`, `set_role`, `leave`

### Ash.Scope plumbing
- [ ] Define `Exhs.Scope` struct holding `actor` and `tenant` (forening_id)
- [ ] Helper for building scope from `conn`/`socket` based on subdomain + current user
- [ ] Document scope-passing convention in `AGENTS.md`

### Subdomain routing
- [ ] Plug that resolves subdomain → forening, assigns to conn
- [ ] LiveView mount hook that does the same for sockets
- [ ] 404 / not-found page when subdomain doesn't match an active forening
- [ ] Reserved subdomains list (`www`, `app`, `admin`, `api`, etc.)
- [ ] Dev-mode handling for `localhost` (path-based fallback? `*.lvh.me`?)

### Superadmin global routes
- [ ] Decide superadmin lives on root domain (`exhs.dk/admin/foreninger`) or a dedicated subdomain (`admin.exhs.dk`)
- [ ] Routes scaffold (UI in Task 17 / a separate superadmin section)

### Migrations
- [ ] Run `mix ash.codegen --dev` iteratively, then a final named migration

### Tests
- [ ] Create forening
- [ ] Membership uniqueness per forening (same user can join multiple foreninger)
- [ ] Tenant attribute is set automatically when scope provided
- [ ] Subdomain plug resolves correctly

## Open decisions
- [ ] **Subdomain dev handling** — `*.lvh.me` works without /etc/hosts edits; commit?
- [ ] **Custom domains** — do foreninger get custom domains in v1, or only `*.exhs.dk`?
- [ ] **Forening archival** — soft-delete or hard-delete? GDPR implications (Task 18)

## Done when
- Two foreninger can coexist with overlapping members
- Tenant attribute auto-populates from scope on all Membership actions
- Subdomain resolution works end-to-end (dev + test)
- Code interface used everywhere; no raw `Ash.` calls in web modules
