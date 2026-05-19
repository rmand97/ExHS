# Task 1 — Project setup & tooling

## Goal
Get a developer from `git clone` to a running app with all dependencies installed, Postgres and Minio running locally via Docker, and CI green.

## Prerequisites
- None (this is the first concrete task)

## Plan

### Toolchain
- [ ] Add `mise.toml` (or `.tool-versions`) pinning Erlang/OTP and Elixir versions
- [ ] Document `mise install` / `mise activate` in README
- [ ] Decide on Node version pin for asset builds and add to mise

### Mix dependencies
- [ ] Confirm/upgrade Phoenix, Ecto, Phoenix LiveView versions in `mix.exs`
- [ ] Add `ash` and `ash_postgres`
- [ ] Add `ash_phoenix`
- [ ] Add `ash_authentication` and `ash_authentication_phoenix`
- [ ] Add `ash_paper_trail` (used heavily in Task 7)
- [ ] Add `ash_oban` + `oban`
- [ ] Add `stripity_stripe` (Stripe SDK)
- [ ] Add `ex_aws`, `ex_aws_s3` (S3/Minio client)
- [ ] Add `swoosh` + chosen adapter (provider TBD — Task 11)
- [ ] Add `ex_slop` (referenced by user)
- [ ] Add `igniter` (dev) — `.igniter.exs` already present
- [ ] Add `usage_rules` (dev) — used in Task 2
- [ ] Add `credo` and `dialyxir` (dev/test) — wired in Task 2
- [ ] Run `mix deps.get` and `mix compile` cleanly

### Local Docker stack
- [ ] Create `docker-compose.yml` at repo root with:
  - [ ] `postgres` service (matching prod major version), volume-mounted data dir, healthcheck
  - [ ] `minio` service exposing API + console ports, default bucket auto-created via `mc` init container
- [ ] Document `docker compose up -d` in README
- [ ] Wire `config/dev.exs` and `config/test.exs` to local Postgres
- [ ] Wire S3 client config to Minio in dev (endpoint, access key, region)

### App configuration
- [ ] Add Ash domains list to `config/config.exs` (`config :exhs, ash_domains: [...]`) — empty list for now, populated by later tasks
- [ ] Configure `Oban` in `config/config.exs` with default queues
- [ ] Set up `.env.example` documenting all env vars (db url, stripe keys, s3 creds, etc.)
- [ ] Decide on env loading strategy (`dotenvy` vs raw `System.get_env`) and apply in `config/runtime.exs`
- [ ] Replace DaisyUI vendor files with Tailwind-component approach is deferred to Task 14; keep current setup running for now

### CI skeleton
- [ ] Add GitHub Actions workflow: `mix deps.get`, `mix compile --warnings-as-errors`, `mix test`, `mix format --check-formatted`
- [ ] Postgres service container in CI
- [ ] Cache deps and `_build`

### Repo hygiene
- [ ] Update README with: prerequisites, setup steps, common commands, architecture pointer (`tasks/00-plan.md`)
- [ ] `.gitignore`: ensure `.env`, `_build`, `deps`, `priv/static/assets`, `cover` are ignored
- [ ] Confirm `mix phx.server` boots against local Docker stack

## Open decisions
- [ ] **Aspire** — does .NET Aspire actually fit here, or is `docker compose` sufficient? Aspire is .NET-centric; revisit in Task 22 if it's for prod orchestration only
- [ ] **Asset pipeline** — keep esbuild/tailwind defaults from Phoenix, or switch?
- [ ] **Node version pin** — required for current asset toolchain version?

## Done when
- Fresh clone → `mise install && mix setup && docker compose up -d && mix phx.server` works
- CI runs green on a trivial PR
- Minio console reachable, default bucket present
- Postgres reachable, repo migrated
