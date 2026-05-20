# Task 3 — Accounts & authentication

## Goal
Global User identity with login/registration via `ash_authentication`. Users are global (not tenant-scoped) — they can belong to many foreninger.

## Prerequisites
- Task 1 (deps), Task 2 (agent guidance and lint)

## Plan

### Accounts domain
- [x] Create `Exhs.Accounts` domain module (`lib/exhs/accounts.ex`)
- [x] Register domain in `config :exhs, ash_domains: [...]`

### User resource
- [x] `Exhs.Accounts.User` resource at `lib/exhs/accounts/user.ex`
- [x] Postgres data layer, table `users`
- [x] Attributes: `id` (uuid), `email` (ci_string, unique), `hashed_password` (sensitive), `first_name`, `last_name`, `phone`, `address_line_1`, `address_line_2`, `postal_code`, `city`, `avatar_url`, `is_superadmin` (boolean, default false), timestamps
- [x] Identity `unique_email`
- [x] Public attributes set correctly (no `hashed_password` public)

### Token resource
- [x] `Exhs.Accounts.Token` per `ash_authentication` docs
- [x] Postgres data layer, table `tokens`

### Authentication strategies
- [x] Password strategy with email identity
- [x] Password reset flow (sender module, email template — provider TBD, see Task 11)
- [x] Magic link strategy (sender module, email template)
- [x] Token resource wired
- [x] Decide on OAuth providers (likely none initially) — deferred to post-MVP

### AshAuthentication.Phoenix integration
- [x] Add `ash_authentication_phoenix` overrides module (existing `auth_overrides.ex` may already cover this)
- [x] Sign-in / register / reset routes wired in `router.ex`
- [x] LiveView session plug for current user
- [x] `live_user_auth.ex` reviewed and extended for current model

### Email sending plumbing
- [x] Swoosh mailer module (provider adapter TBD — Task 11 decides prod adapter; use `Swoosh.Adapters.Local` in dev)
- [x] Sender modules for password reset + magic link + confirmation wire into mailer

### Code interface
- [x] `Exhs.Accounts.register_with_password/2`, `sign_in_with_password/2`, etc., exposed on domain
- [x] `Exhs.Accounts.get_user_by_id!/1`, `update_profile/2` for profile edits

### Tests
- [x] Register / sign in / reset flow tests using globally unique emails (`System.unique_integer/1`)
- [x] Authorization placeholder tests (full policies in Task 5)

## Decided
- **OAuth providers** — not needed for v1; deferred to post-MVP
- **MFA / 2FA** — not required
- **Email confirmation on registration** — yes, enabled via `confirm_new_user` add-on with `confirm_on_create? true`

## Done when
- Can register, log in, log out, request password reset, use magic link, and edit profile
- All actions go through code interface, not raw `Ash.` calls in web layer
- Tests pass; CI green
