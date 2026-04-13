# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0] - 2026-04-13

### Infrastructure

- Six Terraform modules: `ivs`, `s3`, `lambda`, `cloudfront`, `dns`, `monitoring`
- IVS channel (STANDARD, LOW_LATENCY) with 4-hour built-in DVR window; stream key stored in Secrets Manager
- S3 frontend bucket with CloudFront OAC; bucket policy wired in root module to avoid circular dependency
- Lambda function (`nodejs22.x`, 256 MB) with versioned `live` alias and IAM-authenticated function URL
- CloudFront single distribution routing `/hls/*` → IVS, `/api/*` → Lambda, `/*` → S3; Lambda origin secured with SigV4 OAC
- EventBridge rule capturing IVS Stream Start / End / Failure events; Lambda state handler writes stream state to SSM Parameter Store
- CloudWatch alarms for Lambda errors/throttles and CloudFront 5xx rate; SNS topic with optional email subscription
- Optional Route 53 + ACM custom domain (us-east-1 certificate for CloudFront)
- S3 native state locking (`use_lockfile = true`, Terraform 1.10+) — no DynamoDB table required
- `scripts/bootstrap.sh` — idempotent: creates state bucket, GitHub OIDC provider, and least-privilege deploy IAM role; writes `terraform/backend.hcl` and `terraform/terraform.tfvars`

### Backend

- TypeScript Lambda handler (strict mode) with path router: `/api/health`, `/api/stream`, EventBridge dispatch, 404 fallback
- Stream status read from SSM Parameter Store with 10-second in-memory cache; `ParameterNotFound` mapped to `idle`
- Health endpoint returns `{ status, version, region }`; version read from bundled `VERSION` file at runtime
- `src/local.ts` dev server using Node's built-in `http` module; `STREAM_STATUS_MOCK` env var bypasses SSM for credential-free local development

### Frontend

- Vanilla JS player (no build step): Video.js 8 + HLS.js loaded from CDN
- `liveui: true` enables the seekable DVR timeline out of the box; LIVE button snaps to live edge
- Status badge (LIVE / OFFLINE / CONNECTING) driven by `/api/stream` polled every 15 seconds
- Responsive dark-themed layout, 16:9 player container up to 1280px

### CI/CD

- `ci.yml`: lint, TypeScript build, Jest tests, `dist/index.js` existence check, Terraform `validate` + `fmt -check` — runs on every PR to `main`
- `deploy.yml`: tag-triggered (`v*.*.*`) with GitHub OIDC — no stored AWS credentials; parallel `deploy-frontend` (S3 sync + CloudFront invalidation) and `deploy-lambda` (build, prune devDeps, zip, upload, publish version, update `live` alias, CloudFront smoke test); smart path detection skips unchanged components
- Lambda rollback is a single AWS CLI call to point the `live` alias at any previous immutable version

[1.0.0]: https://github.com/mguarinos/streamline/releases/tag/v1.0.0
