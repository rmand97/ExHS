# Task 20 — Observability

## Goal
Know what the system is doing in production: structured logs, metrics, traces, error reporting, alerting.

## Prerequisites
- Task 13 (workers to monitor)

## Plan

### Logging
- [ ] Structured JSON logs in prod (`config :logger, :default_formatter, ...`)
- [ ] Per-request metadata: request_id, user_id, forening_id (tenant), action
- [ ] No PII in logs (redaction allowlist for known sensitive params)
- [ ] Log levels: dev `:debug`, prod `:info` (with `:warning`+ to alerting)

### Metrics
- [ ] `telemetry_metrics_prometheus` (or similar) — Phoenix, Ecto, Oban, custom business metrics
- [ ] Key business metrics:
  - [ ] Active memberships per forening
  - [ ] Kontingent subscription health (active / past_due / canceled)
  - [ ] Newsletter delivery success rate
  - [ ] Webhook processing latency
  - [ ] Stripe API call latency / error rate
- [ ] Metrics endpoint (`/metrics`) scraped by Prometheus / Grafana Cloud

### Traces
- [ ] OpenTelemetry instrumentation for Phoenix + Ecto + Oban + Req
- [ ] Trace context propagation through Oban jobs
- [ ] Sampling strategy (head-based, e.g. 10% + always-trace errors)

### Error reporting
- [ ] Decide tool (Sentry / AppSignal / Honeybadger)
- [ ] Capture user/tenant context on errors (without PII)
- [ ] Source-map upload on deploy

### Application Performance
- [ ] `phoenix_live_dashboard` mounted under superadmin scope
- [ ] Slow-query log threshold configured

### Alerting
- [ ] SLO/error budget for key flows: sign-in, kontingent checkout, newsletter send
- [ ] Pages/notifications wired: Stripe webhook failure rate, Oban queue backlog, error spikes

### Audit ≠ logging
- [ ] Reiterate: business audit goes through `ash_paper_trail` (Task 7); ops logs are technical only

### Tests
- [ ] Telemetry events emitted on key paths
- [ ] Error report captured for a synthetic crash in staging

## Open decisions
- [ ] **Stack choice** — Sentry + Grafana Cloud, vs AppSignal (all-in-one), vs self-hosted (Loki+Tempo+Prometheus)?
- [ ] **Sampling rate** — start with what?
- [ ] **PII redaction** — manual allowlist vs library (`logger_json` config)

## Done when
- Dashboards show key metrics in staging
- A synthetic error in staging reaches the error tool with context
- Oban backlog and webhook failures trigger alerts
