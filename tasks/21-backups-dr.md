# Task 21 — Backups & disaster recovery

## Goal
Postgres point-in-time recovery, S3 object versioning, documented and tested restore procedure.

## Prerequisites
- Task 1 (Postgres + Minio set up), Task 22 (production hosting picked)

## Plan

### Postgres backups
- [ ] Choose mechanism: hosting-provider managed PITR (Neon, Fly, Supabase) vs `pgBackRest`/`barman` on self-hosted
- [ ] RPO target: ≤ 5 minutes
- [ ] RTO target: ≤ 1 hour
- [ ] Daily full + continuous WAL archive
- [ ] Off-region backup copy (EU, GDPR-compliant)
- [ ] Encryption at rest + in transit
- [ ] Retention: 30 days daily, 12 months monthly

### S3 / object storage backups
- [ ] Bucket versioning ON
- [ ] Lifecycle: keep non-current versions 90 days
- [ ] Cross-region replication or scheduled `aws s3 sync` to backup bucket
- [ ] Bucket-level encryption

### Application state
- [ ] No critical state outside Postgres + S3 (verified)
- [ ] Oban jobs are persistent → covered by Postgres backup
- [ ] Stripe data is source-of-truth on Stripe side; reconcile after restore

### Secrets
- [ ] Secrets backed up in a separate, encrypted store (1Password / Vault / SOPS in git)
- [ ] Documented rotation procedure

### Restore drill
- [ ] Quarterly: full restore to staging from production backup
- [ ] Verify integrity, app boots, sample logins work, Stripe reconciliation passes
- [ ] Time the drill against RTO target
- [ ] Runbook at `docs/ops/restore-runbook.md`

### Tests
- [ ] No ExUnit tests for this task — the quarterly restore drill is the test
- [ ] Monitoring/alerting checks that backups ran (covered in Task 20 observability)

### Documentation
- [ ] `docs/ops/dr-plan.md` describing RPO, RTO, scenarios, contacts
- [ ] Tabletop exercise once per year

## Open decisions
- [ ] **Backup tooling** — managed vs self-managed depends on Task 22 hosting decision
- [ ] **Cold-storage** — Glacier/equivalent for long-term retention?
- [ ] **DB engine choice** — vanilla Postgres vs managed Postgres provider impacts this entire task

## Done when
- Backups running on schedule with monitoring
- Restore drill performed and documented
- All ops contacts know where the runbook lives
