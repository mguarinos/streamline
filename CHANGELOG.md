# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2026-04-12

### Infrastructure

- Terraform root module wiring all child modules with S3 + DynamoDB remote state backend
- **module/ivs** — `aws_ivs_channel` (STANDARD, LOW_LATENCY) with built-in 4-hour DVR window; `aws_ivs_stream_key`; stream key stored in Secrets Manager
- **module/s3** — frontend asset bucket with public access blocked, CloudFront OAC, and OAC-scoped bucket policy
- **module/lambda** — IAM execution role, `AWSLambdaBasicExecutionRole` attachment, least-privilege custom policy (IVS `GetStream` + Secrets Manager read), Lambda function, versioned `live` alias, function URL with CORS
- **module/cloudfront** — single distribution with three origins (S3, Lambda function URL, IVS playback); per-path cache behaviours with managed and custom cache policies; `X-Origin-Verify` header for Lambda origin protection; conditional custom domain support
- **module/dns** — ACM certificate (us-east-1, DNS validation), Route 53 validation records, Route 53 A alias record pointing `live.<domain>` to CloudFront
- `scripts/bootstrap.sh` — idempotent bootstrap script: creates Terraform state bucket (versioned, encrypted), DynamoDB lock table, GitHub OIDC provider, least-privilege IAM deploy role, and writes `terraform/backend.hcl`

### Backend

- Lambda handler in TypeScript (Node 20, strict mode) with path-based router (`/api/health`, `/api/stream`, 404 fallback)
- `config.ts` — environment variable validation at cold start with descriptive errors
- `handlers/health.ts` — liveness endpoint returning `{ status, version, region }`; version read from `VERSION` file at runtime
- `handlers/stream.ts` — IVS `GetStreamCommand` integration; `ResourceNotFoundException` mapped to `idle` status; 10-second in-memory cache using `Date.now()` (safe across warm invocations); DVR metadata (`enabled`, `windowSeconds: 14400`) included in every response
- `src/local.ts` — zero-dependency local dev server using Node's built-in `http` module; reads `.env` file manually; proxies requests to the Lambda handler
- DVR support: stream handler always returns the full DVR window metadata; player uses this to configure the seekable timeline UI

### Frontend

- `index.html` — dark-themed, mobile-first player page; Video.js 8 loaded from cdnjs; status badge (LIVE / OFFLINE / CONNECTING); DVR hint bar; offline message
- `style.css` — dark theme (`#0a0a0a`), responsive 16:9 player container (max 1280px), badge states, Video.js control bar overrides keeping the progress/seek bar visible for DVR
- `player.js` (ES module) — polls `/api/stream` every 15 seconds; initialises Video.js with `liveui: true` and VHS options for DVR (`overrideNative`, `enableLowInitialPlaylist`, `handleManifestRedirects`); graceful handling of transient network errors (keeps live player running); player disposal and DOM reconstruction on stream end

### CI/CD

- `ci.yml` — PR workflow: lint, TypeScript build, verify `dist/index.js` exists, Terraform `validate` + `fmt -check`
- `deploy.yml` — tag-triggered (`v*.*.*`) deployment workflow with GitHub OIDC (no stored AWS credentials); parallel `deploy-frontend` (S3 sync with immutable cache headers + CloudFront invalidation) and `deploy-lambda` (build, prune, zip, upload, wait, publish version, update `live` alias) jobs; job summary with rollback command
