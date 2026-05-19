# Task 3 — Accounts & authentication

## Goal
Global User identity with login/registration via `ash_authentication`. Users are global (not tenant-scoped) — they can belong to many foreninger.

## Prerequisites
- Task 1 (deps), Task 2 (agent guidance and lint)

## Plan

### Accounts domain
- [ ] Create `Exhs.Accounts` domain module (`lib/exhs/accounts.ex`)
- [ ] Register domain in `config :exhs, ash_domains: [...]`

### User resource
- [ ] `Exhs.Accounts.User` resource at `lib/exhs/accounts/user.ex`
- [ ] Postgres data layer, table `users`
- [ ] Attributes: `id` (uuid), `email` (ci_string, unique), `hashed_password` (sensitive), `first_name`, `last_name`, `phone`, `address_line_1`, `address_line_2`, `postal_code`, `city`, `avatar_url`, `is_superadmin` (boolean, default false), timestamps
- [ ] Identity `unique_email`
- [ ] Public attributes set correctly (no `hashed_password` public)

### Token resource
- [ ] `Exhs.Accounts.Token` per `ash_authentication` docs
- [ ] Postgres data layer, table `tokens`

### Authentication strategies
- [ ] Password strategy with email identity
- [ ] Password reset flow (sender module, email template — provider TBD, see Task 11)
- [ ] Magic link strategy (sender module, email template)
- [ ] Token resource wired
- [ ] Decide on OAuth providers (likely none initially) — note as deferred

### AshAuthentication.Phoenix integration
- [ ] Add `ash_authentication_phoenix` overrides module (existing `auth_overrides.ex` may already cover this)
- [ ] Sign-in / register / reset routes wired in `router.ex`
- [ ] LiveView session plug for current user
- [ ] `live_user_auth.ex` reviewed and extended for current model

### Email sending plumbing
- [ ] Swoosh mailer module (provider adapter TBD — Task 11 decides prod adapter; use `Swoosh.Adapters.Local` in dev)
- [ ] Sender modules for password reset + magic link wire into mailer

### Code interface
- [ ] `Exhs.Accounts.register_with_password/2`, `sign_in_with_password/2`, etc., exposed on domain
- [ ] `Exhs.Accounts.get_user!/1`, `update_user/2` for profile edits

### Tests
- [ ] Register / sign in / reset flow tests using globally unique emails (`System.unique_integer/1`)
- [ ] Authorization placeholder tests (full policies in Task 5)

## Open decisions
- [ ] **OAuth providers** — needed at launch, or post-MVP?
- [ ] **MFA / 2FA** — required for admins? Built-in via `ash_authentication` add-on?
- [ ] **Email confirmation on registration** — yes/no for v1?

## Done when
- Can register, log in, log out, request password reset, use magic link, and edit profile
- All actions go through code interface, not raw `Ash.` calls in web layer
- Tests pass; CI green
