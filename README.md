# Streamline

**Serverless live streaming platform with 4-hour DVR rewind, built on AWS IVS.**

[![CI](https://github.com/mguarinos/streamline/actions/workflows/ci.yml/badge.svg)](https://github.com/mguarinos/streamline/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/IaC-Terraform_1.10-7B42BC?logo=terraform)](terraform/)
[![Node](https://img.shields.io/badge/Runtime-Node_22-339933?logo=nodedotjs)](lambda/)

---

## Overview

Streamline is a fully serverless live streaming platform that accepts an RTMP feed from any broadcaster (OBS, Larix, GoPro) and delivers it globally via CloudFront with sub-3-second latency. While the stream is live, viewers can drag the timeline to rewind up to 4 hours — IVS maintains this DVR window internally at no extra cost, with no S3 recording bucket required. The entire platform costs nothing at rest and scales automatically under load, making it a practical reference architecture for event streaming without the operational overhead of a media server.

---

## Architecture

```
Broadcaster (OBS · Larix · GoPro)
      │ RTMP
      ▼
   AWS IVS  ──── LL-HLS transcode + 4h DVR window
      │                    │ Stream Start / End
      │                    ▼
      │             EventBridge → Lambda (state handler)
      │                    │
      │                    ▼
      │                SSM Parameter Store
      │                 (stream state)
      ▼
   CloudFront  ── single distribution, three origins
    ├─ /hls/*   →  IVS         (stream + DVR segments, TTL 5s)
    ├─ /api/*   →  Lambda      (stream status API, no cache)
    └─ /*       →  S3          (player page, immutable cache)
                      │
                      ▼
                   Viewer browser
                   Video.js + HLS.js
                   Seekable DVR timeline
```

| Service | Role |
|---|---|
| AWS IVS | RTMP ingest, LL-HLS transcode, 4-hour rolling DVR window |
| CloudFront | Single CDN entry point; routes to three origins by path |
| Lambda | Status API — reads stream state from SSM; EventBridge handler writes state on IVS events |
| EventBridge | Triggers Lambda state handler on IVS Stream Start / End events |
| SSM Parameter Store | Stream state source of truth (`/streamline/{env}/stream-state`) |
| S3 | Hosts the static player page with immutable cache headers |
| Secrets Manager | Stores the IVS stream key as `{"url": "...", "key": "sk_..."}` |
| Route 53 + ACM | Optional custom domain with DNS-validated TLS (us-east-1 cert for CloudFront) |

---

## Tech Stack

| Layer | Technology | Why this choice |
|---|---|---|
| Streaming | AWS IVS (STANDARD, LOW latency) | Managed RTMP ingest + HLS transcode; built-in 4h DVR at no extra cost |
| DVR | IVS internal rolling window | No S3 bucket, no recording config, no retention policy — zero operational cost |
| CDN | CloudFront (single distribution) | One distribution handles HLS, API, and static assets; simplifies DNS and TLS |
| API | Node 22 Lambda + TypeScript | Cold start < 200ms; EventBridge state handler; versioned alias enables instant rollback |
| Origin security | CloudFront OAC + Lambda `AWS_IAM` URL auth | CloudFront signs every API request with SigV4; Lambda rejects anything not from this distribution |
| Frontend | Vanilla JS, Video.js 8, HLS.js | No build step; `liveui: true` enables the seekable DVR timeline out of the box |
| IaC | Terraform 1.10, modular layout | Five focused modules (ivs/s3/lambda/cloudfront/dns); S3 native state locking (no DynamoDB) |
| CI/CD | GitHub Actions + OIDC | No long-lived AWS credentials; tag-triggered deploys; parallel frontend + Lambda jobs |
| DNS/TLS | Route 53 + ACM | Automated DNS validation; ACM cert provisioned in us-east-1 for CloudFront requirement |

---

## DVR Behaviour

- **While the stream is live**, viewers can drag the Video.js progress bar left to rewind up to **4 hours**. The timeline is fully seekable.
- **IVS maintains this window internally** on its own infrastructure. There is no `recording_configuration_arn`, no S3 recording bucket, and no extra cost. The 4-hour DVR window is a built-in property of STANDARD-type IVS channels.
- The HLS manifest IVS generates contains the full seekable range. The Video.js VHS engine reads this automatically — no special URL parameters or player configuration beyond `liveui: true` are required.
- Clicking the **LIVE** button in the player snaps back to the live edge instantly.
- **After the stream ends**, DVR segments are discarded. This is intentional: no storage costs, no retention policy, no GDPR surface area for recorded content.

---

## Prerequisites

| Tool | Version |
|---|---|
| AWS CLI | 2+ (configured with an IAM user or role) |
| Terraform | 1.10+ |
| Node.js | 22+ |
| npm | 10+ |
| Git | Any recent version |
| Route 53 hosted zone | Optional — only required for a custom domain |

---

## First-Time Setup

### 1. Clone

```bash
git clone https://github.com/mguarinos/streamline.git
cd streamline
```

### 2. Bootstrap AWS infrastructure

The bootstrap script creates the Terraform state bucket (with native S3 locking — no DynamoDB required), GitHub OIDC provider, and least-privilege IAM deploy role. It also builds the initial Lambda zip so the first `terraform apply` succeeds without a separate CI run. Fully idempotent — safe to re-run.

```bash
./scripts/bootstrap.sh
```

You will be prompted for AWS region, environment name, and your GitHub org/repo. The script writes `terraform/backend.hcl` and `terraform/terraform.tfvars` on completion.

### 3. Initialise Terraform

```bash
cd terraform
terraform init -backend-config=backend.hcl
```

### 4. Plan and apply

```bash
terraform plan
terraform apply
```

`bootstrap.sh` writes a `terraform.tfvars` with your environment and region, so no `-var` flags are needed. To enable optional features, uncomment the relevant lines in `terraform/terraform.tfvars` before applying:

```hcl
# domain_name    = "example.com"
# hosted_zone_id = "Z0123456789ABCDEF"
# alarm_email    = "ops@example.com"
```

A single `terraform apply` is all you need — the S3 bucket policy and CloudFront→Lambda permission are managed in the root module so Terraform resolves the dependency order automatically.

### 5. Note the outputs

```bash
terraform output
```

Key outputs:

| Output | Used for |
|---|---|
| `ingest_endpoint` | OBS/Larix Server field |
| `cloudfront_url` | Share with viewers |
| `s3_bucket_name` | GitHub variable |
| `retrieve_stream_key_command` | Get the stream key from Secrets Manager |

### 6. Add GitHub secrets and variables

In your repository → **Settings → Secrets and variables → Actions**:

**Secrets** (sensitive — _New repository secret_):

| Secret | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Printed by `bootstrap.sh` |

**Variables** (non-sensitive — _New repository variable_):

| Variable | Value |
|---|---|
| `AWS_REGION` | e.g. `eu-west-1` |
| `S3_BUCKET_NAME` | From `terraform output -raw s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | `terraform state show module.cloudfront.aws_cloudfront_distribution.this \| grep '^id'` |
| `LAMBDA_FUNCTION_NAME` | `streamline-{environment}` — matches the value you set in `terraform.tfvars` (e.g. `streamline-prod`) |

### 7. Trigger the first deploy

```bash
git tag v0.1.0 && git push origin v0.1.0
```

The `deploy.yml` workflow runs: builds the Lambda zip, syncs the frontend to S3, invalidates CloudFront, publishes a Lambda version, and points the `live` alias at it. It also runs a smoke test through CloudFront once done.

Manual deploys are also supported: **Actions → Deploy → Run workflow** with per-component toggles.

### 8. Configure OBS

In OBS → **Settings → Stream → Custom**:

| Field | Value |
|---|---|
| Server | Paste `ingest_endpoint` from Terraform output |
| Stream Key | Run the `retrieve_stream_key_command` output |

---

## Security

The Lambda Function URL uses `authorization_type = "AWS_IAM"`. Access is granted exclusively to `cloudfront.amazonaws.com` with a condition on this specific distribution's ARN. CloudFront uses an OAC (Origin Access Control) to sign every request to the Lambda origin with SigV4 before forwarding it — requests arriving at the function URL from any other source are rejected by IAM before they reach the function code.

---

## Deployment & Versioning

Every production deploy is triggered by a semver tag:

```bash
git tag v1.2.0 && git push origin v1.2.0
```

The workflow runs three jobs:

1. **prepare** — extracts semver + short SHA, uploads a `VERSION` artifact
2. **deploy-frontend** *(parallel)* — syncs assets to S3 with immutable cache headers, syncs `index.html` with `must-revalidate`, invalidates CloudFront
3. **deploy-lambda** *(parallel)* — builds TypeScript, prunes devDependencies, zips `dist/` + `node_modules/` + `VERSION`, uploads to Lambda, waits for propagation, publishes an immutable version snapshot, updates the `live` alias, runs smoke test through CloudFront

Each Lambda version is immutable. Rollback is a single AWS CLI call:

```bash
aws lambda update-alias \
  --function-name streamline-prod \
  --name live \
  --function-version PREVIOUS_VERSION_NUMBER
```

---

## Local Development

```bash
cd lambda
cp .env.example .env
npm install
npm run dev              # starts http server on :3001
```

Then open `frontend/index.html` directly in a browser (no local server needed for the frontend).

`STREAM_STATUS_MOCK=idle` in `.env.example` bypasses the SSM call so the server works without AWS credentials. Change it to `live` to test the player in live mode.

Available endpoints:

```
GET http://localhost:3001/api/health   → { status, version, region }
GET http://localhost:3001/api/stream   → { playbackUrl, status, dvr }
```

---

## License

MIT — see [LICENSE](LICENSE).
