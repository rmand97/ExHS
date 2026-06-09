# Task 0 — Master Plan

This file indexes all tasks. Each task is a self-contained chunk of work with its own checklist. Tasks should generally be done in order; explicit prerequisites are listed in each file.

## Conventions

- App name: `exhs` (modules: `Exhs`, paths: `lib/exhs/`)
- Each task file has: **Goal**, **Prerequisites**, **Plan** (checkboxes), **Open decisions** (where relevant), **Done when**
- Mark items with `[x]` as you complete them
- If a task spawns new work, add it to the relevant task file rather than creating ad-hoc TODOs
- "TBD" markers are intentional — do not invent answers; surface to the user

## Task Index

Legend: `[x]` core delivered (residuals deferred to a dependent task or tracked in-file) · `[~]` in progress · `[ ]` not started.

### Foundations
- [x] [Task 1 — Project setup & tooling](./01-project-setup.md) — core complete; CI green + boot smoke test deferred
- [x] [Task 2 — AI-driven dev setup](./02-ai-dev-setup.md)

### Core domain
- [x] [Task 3 — Accounts & authentication](./03-accounts-auth.md) — password + magic link + confirmation, superadmin flag
- [x] [Task 4 — Organizations core & multitenancy](./04-organizations-core.md) — attribute multitenancy, subdomain plug, scope
- [x] [Task 5 — Roles & policies](./05-roles-policies.md) — admin/board/member, HasMembershipRole, Superadmin bypass
- [x] [Task 6 — Groups & tagging](./06-groups-tagging.md)
- [x] [Task 7 — Audit trail](./07-audit-trail.md) — AshEvents event log live; forening-wide UI is Task 24

### Business domains
- [x] [Task 8 — Billing & Stripe](./08-billing-stripe.md) — Connect onboarding, subscriptions, payments, webhooks
- [x] [Task 9 — Events](./09-events.md) — domain + admin & public UI; paid-ticket wiring pending Task 25
- [x] [Task 25 — Ticket purchasing & checkout](./25-ticketing.md) — Order/OrderItem aggregate, presales, holds, Stripe checkout + webhook, live availability, admin mgmt (live waitlist-position in buyer UI deferred)

### Nice-to-have (post-launch)
- [ ] [Task 10 — Shop (mostly TBD)](./10-shop.md) — not started
- [ ] [Task 11 — Communications & newsletters](./11-communications.md) — not started

### Quality
- [ ] [Task 26 — End-to-end (browser) testing](./26-e2e-testing.md) — Playwright E2E layer; JS + full journeys against a running server

### Cross-cutting infrastructure
- [~] [Task 12 — File uploads & S3/Minio](./12-uploads-s3.md) — storage + S3 client + presign helper done; upload LiveViews (logo/banner/cover/avatar) deferred
- [x] [Task 13 — Background jobs (Oban)](./13-oban-workers.md) — queues + core workers (invite, waitlist, webhooks, upload cleanup, membership deactivation); newsletter/GDPR/orphan-sweeper workers pending their tasks

### UI layer
- [x] [Task 14 — Design system](./14-design-system.md)
- [x] [Task 15 — Public forening pages](./15-public-ui.md) — home/events/join live; shop pages deferred (Task 10)
- [x] [Task 16 — Member self-service UI](./16-member-ui.md) — dashboard, profile, registrations, payments, cross-forening handoff; live Stripe self-service + avatar upload pending
- [~] [Task 17 — Admin dashboard UI](./17-admin-ui.md) — **in progress**: Members, Groups, Settings, Economy, Events, and Superadmin slices done (built, tested, audit-logged). Remaining: Shop, Newsletters, Audit UI, and logo/cover image uploads

### Admin tools (pre-deploy)
- [ ] [Task 23 — Merge duplicate user accounts](./23-merge-users.md) — not started
- [ ] [Task 24 — Audit trail UI](./24-audit-trail-ui.md) — not started (per-record history panel already in Task 17 member detail)

### Compliance & ops
- [ ] [Task 18 — GDPR & data retention](./18-gdpr-retention.md) — not started
- [ ] [Task 19 — Internationalization](./19-i18n.md) — not started (UI is Danish-only, no gettext extraction yet)
- [ ] [Task 20 — Observability](./20-observability.md) — not started
- [ ] [Task 21 — Backups & DR](./21-backups-dr.md) — not started
- [ ] [Task 22 — Deployment & CI/CD](./22-deployment.md) — not started

## Global open decisions

These are unresolved cross-cutting questions. Each is also surfaced inside the relevant task file.

- [ ] **Hosting** — Fly.io, Gigalixir, self-hosted on Hetzner, …? (Task 22)
- [ ] **Email provider** — Postmark, Resend, AWS SES, …? (Task 11)
- [ ] **S3 provider in prod** — AWS S3, Cloudflare R2, Backblaze B2, Hetzner Object Storage? (Task 12)
- [ ] **PDF generation** — Needed for invoices/receipts? Library/service choice? (Task 8)
- [ ] **Observability stack** — Sentry, AppSignal, OpenTelemetry collector, Grafana Cloud? (Task 20)
- [ ] **Shop scope** — Physical vs digital, digital delivery mechanism, returns flow (Task 10)

## Decided

- **Docker Compose** — local-infrastructure orchestrator for Postgres + Minio. Not used in production.
- **No event sourcing** — AshEvents stays as audit log only. Full event sourcing (replay, projections) rejected: CRUD-heavy domain doesn't benefit, Stripe state is external and non-replayable, GDPR conflicts with immutable event logs, per-tenant replay unsupported upstream. Centralized audit table is the right tradeoff.
