# Task 22 — Deployment & CI/CD

## Goal
Repeatable, automated deploys to staging and production with zero-downtime. CI runs all checks; CD promotes on green main + manual approval for prod.

## Prerequisites
- Tasks 1, 2 (CI skeleton + linting); really every prior task should be at least scaffolded so it gets exercised in CI

## Plan

### Hosting choice (decide first)
- [ ] Evaluate: Fly.io (EU regions, easy LV clustering), Gigalixir (Elixir-native, less EU-strong), Render, Hetzner Cloud (self-managed via Kamal/Docker), AWS ECS/EKS
- [ ] EU data residency is required (GDPR) — narrows the field
- [ ] Cost model and operational burden compared
- [ ] **Decision needed before this task can proceed**

### Release configuration
- [ ] `mix release` configured with appropriate runtime
- [ ] Multi-stage Dockerfile (build → release → distroless or alpine runtime)
- [ ] Smaller image: only `priv/`, `lib/`, static assets, BEAM runtime
- [ ] Health check endpoint (`/health`, `/ready`)

### Runtime config
- [ ] All secrets via env vars (`config/runtime.exs`)
- [ ] `RELEASE_COOKIE` + `DATABASE_URL` + Stripe + S3 + email creds + secret key base
- [ ] Documented in deployment runbook

### Database migrations
- [ ] `Exhs.Release` module with `migrate/0`, `rollback/2`
- [ ] Migrations run as a pre-deploy step (one node, before rollout)
- [ ] Ash codegen output checked in; CI verifies no uncommitted resource changes

### Zero-downtime
- [ ] Rolling deploy; LV connections reconnect transparently
- [ ] Pre-stop hook to drain
- [ ] Migrations always backward-compatible (no destructive in same deploy as code using old shape)

### CI pipeline (GitHub Actions)
- [ ] On PR: format, compile --warnings-as-errors, credo --strict, dialyzer (cached), test (with Postgres service), usage_rules sync check, assets build
- [ ] On main: above + build & push image, deploy to staging
- [ ] Manual workflow: promote staging image → production

### Aspire (local only — settled in Task 1)
- Aspire is the **local-infrastructure orchestrator** (Postgres + Minio); it is **not** used in production.
- Prod uses hosting-provider primitives (chosen above). No carry-over of Aspire concepts.

### Tests
- [ ] No ExUnit tests for deployment itself — CI runs the whole test suite on every PR, that's the gate
- [ ] Smoke check after each deploy: hit `/health` and one authenticated route on staging before promoting to prod
- [ ] Rollback procedure executed at least once on staging to verify it works

### Staging environment
- [ ] Separate cluster/region from prod
- [ ] Production-like config but with test Stripe keys and Minio (or staging bucket)
- [ ] Seed script for staging demo data

### Domains & TLS
- [ ] Wildcard cert for `*.exhs.dk`
- [ ] DNS provider with API access for automation
- [ ] Optional: custom domain support per forening (Task 4 open question)

### Secrets management
- [ ] Per-environment secret store (provider-native or 1Password CLI / Doppler / SOPS)
- [ ] Rotation playbook
- [ ] Audit of access

### Deployment runbook
- [ ] `docs/ops/deploy.md`: how to deploy, how to rollback, how to read logs, where dashboards live
- [ ] On-call expectations

## Open decisions
- [ ] **Hosting platform** — biggest blocker for this task
- [ ] **Containerization vs native release** — depends on hosting choice
- [ ] **Cluster size & autoscaling**

## Done when
- One-button deploy to staging from main
- Promote-to-prod workflow exists with manual approval gate
- Rollback procedure documented and tested
- All env-specific config externalized
