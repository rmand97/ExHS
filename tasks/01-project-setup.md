# Task 1 — Project setup & tooling

## Goal
Get a developer from `git clone` to a running app with all dependencies installed, Postgres and Minio running locally via Docker, and CI green.

## Prerequisites
- None (this is the first concrete task)

## Plan

### Toolchain
- [x] Add `mise.toml` pinning Erlang/OTP (28) and Elixir (1.19.5-otp-28)
- [x] Document `mise install` in README
- [x] Pin Node (22) in mise for asset builds

### Mix dependencies
- [x] Phoenix 1.8 / Ecto / LiveView 1.1 already in place
- [x] `ash` and `ash_postgres` already present
- [x] `ash_phoenix` already present
- [x] `ash_authentication` and `ash_authentication_phoenix` already present
- [x] Add `ash_paper_trail` (replaced by `ash_events` in Task 7)
- [x] Add `ash_events` (centralized event log — Task 7)
- [x] Add `ash_oban` + `oban`
- [x] Add `stripity_stripe`
- [x] Add `ex_aws`, `ex_aws_s3`, `sweet_xml`
- [x] `swoosh` already present (adapter selection deferred to Task 11)
- [x] Add `ex_slop`
- [x] `igniter` already present
- [x] `usage_rules` already present
- [x] Add `ash_ai`
- [x] Add `tidewave` (dev)
- [ ] Wire Tidewave MCP endpoint in dev (Phoenix endpoint plug) — see Tidewave README; document MCP connection in `CLAUDE.md`
- [x] Add `credo` and `dialyxir` (dev/test)
- [x] Add `dotenvy`
- [x] `mix deps.get` ran cleanly
- [ ] `mix compile` (deferred — user setting up local infra; verify after Docker up)

### Local infrastructure

**Decision: .NET Aspire is the primary local orchestrator.** `docker-compose.yml` is kept as a fallback for non-Aspire users and as a reference for the same services.

#### Aspire AppHost (primary)
- [ ] Create Aspire AppHost project (location TBD — sibling `aspire/` directory? Decide path)
- [ ] AppHost resources:
  - [ ] Postgres 17 with persistent volume; exposed on `localhost:5432`; user/pass/db match `config/dev.exs`
  - [ ] Minio with persistent volume; exposed on `localhost:9000` (API) and `localhost:9001` (console); creds `minioadmin/minioadmin`
  - [ ] Minio bucket bootstrap: `exhs-dev`, `exhs-test`
- [ ] Document `dotnet run --project aspire/...` in README, replacing the `docker compose up -d` step (compose stays as fallback)
- [ ] CI still uses GH Actions postgres service container (Aspire is local-only)

#### Docker compose (fallback)
- [x] `docker-compose.yml` at repo root with:
  - [x] `postgres` service (17-alpine), volume-mounted data dir, healthcheck
  - [x] `minio` service exposing API + console ports, default bucket auto-created via `mc` init container (creates `exhs-dev` and `exhs-test`)
- [x] Document `docker compose up -d` in README as the fallback path
- [x] `config/dev.exs` and `config/test.exs` already pointed at local Postgres (matches both)
- [x] Wire S3 client config to Minio in dev/test (endpoint, access key, region)

### App configuration
- [x] `ash_domains` list in `config/config.exs` (currently `[Exhs.Accounts]`; later tasks append)
- [x] Configure `Oban` in `config/config.exs` with queues `default`, `mailers`, `webhooks`, `stripe`, `gdpr`, `maintenance`
- [x] Oban added to supervision tree in `lib/exhs/application.ex`
- [x] Oban `testing: :inline` set in `config/test.exs`
- [x] `.env.example` documenting Stripe + S3 env vars
- [x] Env loading via `dotenvy` in `config/runtime.exs` for dev/test
- [x] Stripe and S3 env-driven config in `config/runtime.exs`
- [ ] DaisyUI removal deferred to Task 14

### CI skeleton
- [x] `.github/workflows/ci.yml` runs `deps.get`, `compile --warnings-as-errors`, `format --check-formatted`, `deps.unlock --check-unused`, `credo --strict` (soft-fail for now), `test`
- [x] Postgres 17 service container
- [x] Deps + `_build` cache keyed on `mix.lock`

### Tests
- [ ] Trivial smoke test: `mix test` passes on a freshly-set-up clone (Postgres + Oban + `Exhs.Application` boot without errors)
- [ ] CI green on the skeleton

### Repo hygiene
- [x] README updated with prerequisites, setup steps, common commands, pointer to `tasks/00-plan.md`
- [x] `.gitignore` ignores `.env`, `.env.*` (keeps `.env.example`), `priv/plts/`, editor folders
- [ ] `mix phx.server` smoke test (deferred — user setting up local Docker stack)

## Open decisions
- [ ] **Aspire AppHost location** — sibling `aspire/` dir vs separate repo?
- [ ] **Asset pipeline** — keep esbuild/tailwind defaults from Phoenix, or switch?

## Decided
- **Aspire** is the primary local infrastructure orchestrator (Postgres + Minio). Docker compose kept as fallback. Not used in production (see Task 22).
- **Toolchain**: Elixir 1.19.5 / OTP 28 / Node 22 via `mise`.
- **Postgres**: 17.
- **Env loading**: `dotenvy` in dev/test runtime config.

## Done when
- Fresh clone → `mise install && mix setup && docker compose up -d && mix phx.server` works
- CI runs green on a trivial PR
- Minio console reachable, default bucket present
- Postgres reachable, repo migrated
