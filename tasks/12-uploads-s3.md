# Task 12 — File uploads & S3/Minio

## Goal
Uniform file upload pipeline backed by S3-compatible storage (Minio in dev, real S3-compatible provider in prod). Used for avatars, forening branding, event covers, product images, and (future) digital product files.

## Prerequisites
- Task 1 (Minio running locally)

## Plan

### Storage adapter
- [ ] Wrap `ex_aws_s3` in a thin internal module `Exhs.Storage`
- [ ] Config-driven endpoint/bucket/region so dev=Minio, prod=real provider
- [ ] Operations: `put`, `get_signed_url`, `delete`, `head`

### Upload flow (Phoenix LiveView)
- [ ] Use LiveView's external upload with presigned PUT to S3/Minio
- [ ] Client uploads directly to storage (no proxying through app server)
- [ ] On success, store the object key on the resource

### File model
- [ ] Decide: store keys directly on owning resources (`avatar_url`, `cover_image_url`) OR introduce a generic `Exhs.Storage.Attachment` resource
- [ ] Recommendation: store keys on owners for v1; add Attachment resource only if needed later

### Image transformations
- [ ] Decide on resizing approach: on-the-fly via `imgproxy`/`imageflow`, or pre-generated variants on upload
- [ ] Recommendation: on-the-fly via imgproxy sidecar (added to Docker compose in Task 1) — simpler and cacheable

### Access control
- [ ] Public-read for branding/event covers/product images (URLs can be CDN-cached)
- [ ] Private + presigned URLs for any sensitive uploads (digital product downloads — Task 10)
- [ ] Bucket policy / per-object ACL strategy documented

### Cleanup
- [ ] When a resource is destroyed, delete the underlying object (after_action or Oban worker)
- [ ] Orphan-sweeper Oban job (Task 13)

### Tests
S3 is an external dep — test thoroughly against local Minio (the same protocol as prod S3).

- [ ] Upload roundtrip against Minio in test env
- [ ] Presigned URL works and expires
- [ ] Deleting a resource removes its object
- [ ] Failure paths: network error, 4xx (e.g. forbidden), 5xx — verify we don't leak orphans on the DB side
- [ ] Orphan-sweeper job removes objects without a referencing resource and only those
- [ ] File-size limit enforced before we hit the bucket

## Open decisions
- [ ] **Prod S3 provider** — AWS S3, Cloudflare R2 (zero egress), Backblaze B2 (cheap), Hetzner Object Storage (EU)
- [ ] **CDN** — Cloudflare in front of bucket? BunnyCDN?
- [ ] **Image transformation** — imgproxy vs Phoenix-side via `image`/`vix`?
- [ ] **EU data residency** — GDPR pushes us toward EU-located buckets; R2/Hetzner/Scaleway?
- [ ] **Max file sizes** — per upload type

## Done when
- Avatar upload works in dev against Minio
- Forening branding upload works
- Resources reference uploads by stable keys
- Deletion cleans up storage
