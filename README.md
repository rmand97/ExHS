# Exhs

Multi-organization platform for Danish foreninger. See [`tasks/00-plan.md`](./tasks/00-plan.md) for scope, domain breakdown, and the full implementation roadmap.

## Prerequisites

- [mise](https://mise.jdx.dev/) — tool version manager
- Docker + Docker Compose — for local Postgres and Minio (S3-compatible)

## First-time setup

```sh
# Install Erlang, Elixir, Node per mise.toml
mise trust
mise install

# Start local services
docker compose up -d

# Install deps and run setup
mix setup

# Start the dev server
mix phx.server
```

Visit [`localhost:4000`](http://localhost:4000).

## Common commands

- `mix phx.server` — start Phoenix dev server
- `mix test` — run tests
- `mix precommit` — compile (warnings as errors), unlock unused deps, format, test
- `mix ash.codegen --dev` — generate dev migrations after resource changes
- `mix ash.migrate` — apply migrations
- `docker compose up -d` — start Postgres + Minio
- `docker compose down` — stop them

## Project orientation

- `tasks/00-plan.md` — task index and global open decisions
- `CLAUDE.md` — project-specific agent rules
- `.claude/skills/` — dep usage rules (synced via `mix usage_rules.sync`)

## Tooling

- Elixir 1.19 / OTP 28 (see `mise.toml`)
- Phoenix 1.8 with LiveView 1.1
- Ash 3.x + ash_postgres + ash_authentication + ash_events (~> 0.7) + ash_oban
- Postgres 17 (Docker)
- Minio (Docker) — S3-compatible local storage
- Stripe for payments
- Oban for background jobs
- Tailwind CSS 4 + DaisyUI v5
