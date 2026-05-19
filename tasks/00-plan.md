# Task 0 — Master Plan

This file indexes all tasks. Each task is a self-contained chunk of work with its own checklist. Tasks should generally be done in order; explicit prerequisites are listed in each file.

## Conventions

- App name: `exhs` (modules: `Exhs`, paths: `lib/exhs/`)
- Each task file has: **Goal**, **Prerequisites**, **Plan** (checkboxes), **Open decisions** (where relevant), **Done when**
- Mark items with `[x]` as you complete them
- If a task spawns new work, add it to the relevant task file rather than creating ad-hoc TODOs
- "TBD" markers are intentional — do not invent answers; surface to the user

## Task Index

### Foundations
- [ ] [Task 1 — Project setup & tooling](./01-project-setup.md)
- [ ] [Task 2 — AI-driven dev setup](./02-ai-dev-setup.md)

### Core domain
- [ ] [Task 3 — Accounts & authentication](./03-accounts-auth.md)
- [ ] [Task 4 — Organizations core & multitenancy](./04-organizations-core.md)
- [ ] [Task 5 — Roles & policies](./05-roles-policies.md)
- [ ] [Task 6 — Groups & tagging](./06-groups-tagging.md)
- [ ] [Task 7 — Audit trail](./07-audit-trail.md)

### Business domains
- [ ] [Task 8 — Billing & Stripe](./08-billing-stripe.md)
- [ ] [Task 9 — Events](./09-events.md)
- [ ] [Task 10 — Shop (mostly TBD)](./10-shop.md)
- [ ] [Task 11 — Communications & newsletters](./11-communications.md)

### Cross-cutting infrastructure
- [ ] [Task 12 — File uploads & S3/Minio](./12-uploads-s3.md)
- [ ] [Task 13 — Background jobs (Oban)](./13-oban-workers.md)

### UI layer
- [ ] [Task 14 — Design system](./14-design-system.md)
- [ ] [Task 15 — Public forening pages](./15-public-ui.md)
- [ ] [Task 16 — Member self-service UI](./16-member-ui.md)
- [ ] [Task 17 — Admin dashboard UI](./17-admin-ui.md)

### Compliance & ops
- [ ] [Task 18 — GDPR & data retention](./18-gdpr-retention.md)
- [ ] [Task 19 — Internationalization](./19-i18n.md)
- [ ] [Task 20 — Observability](./20-observability.md)
- [ ] [Task 21 — Backups & DR](./21-backups-dr.md)
- [ ] [Task 22 — Deployment & CI/CD](./22-deployment.md)

## Global open decisions

These are unresolved cross-cutting questions. Each is also surfaced inside the relevant task file.

- [ ] **Hosting** — Fly.io, Gigalixir, self-hosted on Hetzner, …? (Task 22)
- [ ] **Email provider** — Postmark, Resend, AWS SES, …? (Task 11)
- [ ] **S3 provider in prod** — AWS S3, Cloudflare R2, Backblaze B2, Hetzner Object Storage? (Task 12)
- [ ] **PDF generation** — Needed for invoices/receipts? Library/service choice? (Task 8)
- [ ] **Observability stack** — Sentry, AppSignal, OpenTelemetry collector, Grafana Cloud? (Task 20)
- [ ] **Shop scope** — Physical vs digital, digital delivery mechanism, returns flow (Task 10)
- [ ] **Aspire usage** — How does .NET Aspire fit into an Elixir stack? Is this for orchestration of supporting services only? (Task 1 / Task 22)
