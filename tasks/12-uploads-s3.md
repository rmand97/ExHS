# Task 12 — File uploads & S3/Minio

## Goal
Uniform file upload pipeline backed by S3-compatible storage (Minio in dev, real S3-compatible provider in prod). Used for avatars, forening branding, event covers, product images, and (future) digital product files.

## Prerequisites
- Task 1 (Minio running locally)

## Plan

### Storage adapter
- [x] Wrap `ex_aws_s3` in a thin internal module `Exhs.Storage` (behaviour + delegator)
- [x] Config-driven endpoint/bucket/region so dev=Minio, prod=real provider
- [x] Operations: `put`, `presigned_put_url`, `delete`, `head`
- [x] `Exhs.Storage.S3` live implementation
- [x] `Exhs.Storage.Stub` test stub (Process dictionary, follows StripeClient.Stub pattern)
- [x] `public_url/1` and `generate_key/4` helpers

### Upload flow (Phoenix LiveView)
- [x] `ExhsWeb.UploadHelpers` — shared presigner + consume logic
- [x] S3 external uploader added to `assets/js/app.js`
- [x] CORS configured on Minio via `MINIO_API_CORS_ALLOW_ORIGIN`
- [ ] LiveView pages (deferred — SettingsLive, ForeningSettingsLive, EventFormLive)

### File model
- [x] **Decided: store keys on owners for v1** — no generic Attachment resource
- [x] Added explicit `logo_url` and `banner_url` string attributes to Forening (migration: `add_forening_branding_urls`)

### Image transformations
- [x] **Decided: defer imgproxy** — upload originals only; add transforms later

### Access control
- [x] Public-read for branding/event covers/product images (Minio buckets have anonymous download policy)
- [ ] Private + presigned URLs for any sensitive uploads (digital product downloads — Task 10)
- [ ] Bucket policy / per-object ACL strategy documented

### Cleanup
- [x] `Exhs.Storage.CleanupWorker` — Oban worker for async S3 deletion
- [x] `ExhsWeb.UploadHelpers.maybe_cleanup_old_key/2` — enqueues cleanup when key replaced
- [ ] Orphan-sweeper Oban job (Task 13)

### Tests
S3 is an external dep — test thoroughly against local Minio (the same protocol as prod S3).

- [x] Upload roundtrip against Minio in test env
- [x] Presigned URL works
- [x] Delete removes object, idempotent on nonexistent
- [x] Stub roundtrip and override tests
- [x] CleanupWorker perform + enqueue tests
- [ ] Failure paths: network error, 4xx, 5xx — partial coverage via stub overrides
- [ ] Orphan-sweeper job removes objects without a referencing resource and only those
- [ ] File-size limit enforced before we hit the bucket

## Open decisions
- [ ] **Prod S3 provider** — AWS S3, Cloudflare R2 (zero egress), Backblaze B2 (cheap), Hetzner Object Storage (EU)
- [ ] **CDN** — Cloudflare in front of bucket? BunnyCDN?
- [x] **Image transformation** — deferred; upload originals only for now
- [ ] **EU data residency** — GDPR pushes us toward EU-located buckets; R2/Hetzner/Scaleway?
- [x] **Max file sizes** — 5MB avatars, 10MB covers/branding (configured in `allow_upload` when LiveViews added)

## Done when
- Avatar upload works in dev against Minio
- Forening branding upload works
- Resources reference uploads by stable keys
- Deletion cleans up storage
