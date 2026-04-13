# Streamline

**Serverless live streaming platform with 4-hour DVR rewind, built on AWS IVS.**

[![CI](https://github.com/YOUR_ORG/streamline/actions/workflows/ci.yml/badge.svg)](https://github.com/YOUR_ORG/streamline/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/IaC-Terraform_1.10-7B42BC?logo=terraform)](terraform/)
[![Node](https://img.shields.io/badge/Runtime-Node_24-339933?logo=nodedotjs)](lambda/)

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
      │
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
| Lambda | Stateless status API — polls IVS `GetStream`, returns live/idle + DVR metadata |
| S3 | Hosts the static player page with immutable cache headers |
| Secrets Manager | Stores the IVS stream key; never exposed in Terraform state |
| Route 53 + ACM | Optional custom domain with DNS-validated TLS (us-east-1 cert for CloudFront) |

---

## Tech Stack

| Layer | Technology | Why this choice |
|---|---|---|
| Streaming | AWS IVS (STANDARD, LOW_LATENCY) | Managed RTMP ingest + HLS transcode; built-in 4h DVR at no extra cost |
| DVR | IVS internal rolling window | No S3 bucket, no recording config, no retention policy — zero operational cost |
| CDN | CloudFront (single distribution) | One distribution handles HLS, API, and static assets; simplifies DNS and TLS |
| API | Node 20 Lambda + TypeScript | Cold start < 200ms; 10s timeout covers IVS SDK latency; versioned alias enables instant rollback |
| Frontend | Vanilla JS, Video.js 8, HLS.js | No build step; `liveui: true` enables the seekable DVR timeline out of the box |
| IaC | Terraform 1.7, modular layout | Five focused modules (ivs/s3/lambda/cloudfront/dns); S3 + DynamoDB remote state |
| CI/CD | GitHub Actions + OIDC | No long-lived AWS credentials; tag-triggered deploys; parallel frontend + Lambda jobs |
| DNS/TLS | Route 53 + ACM | Automated DNS validation; ACM cert provisioned in us-east-1 for CloudFront requirement |

---

## DVR Behaviour

This is the most architecturally interesting aspect of the platform.

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
| Terraform | 1.7+ |
| Node.js | 20+ |
| Git | Any recent version |
| Route 53 hosted zone | Optional — only required for a custom domain |

---

## First-Time Setup

### 1. Clone

```bash
git clone https://github.com/YOUR_ORG/streamline.git
cd streamline
```

### 2. Bootstrap AWS infrastructure

The bootstrap script creates the Terraform state bucket (with native S3 locking — no DynamoDB required), GitHub OIDC provider, and least-privilege IAM deploy role. It also builds the initial Lambda zip so the first `terraform apply` succeeds without a separate CI run. Fully idempotent — safe to re-run.

```bash
./scripts/bootstrap.sh
```

You will be prompted for AWS region, environment name, and your GitHub org/repo. The script writes `terraform/backend.hcl` on completion.

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

A single `terraform apply` is all you need — the S3 bucket policy is managed in the root module so Terraform resolves the dependency order automatically.

### 5. Note the outputs

```bash
terraform output
```

Key outputs:

| Output | Used for |
|---|---|
| `ingest_endpoint` | OBS/Larix Server field |
| `cloudfront_url` | Share with viewers |
| `s3_bucket_name` | GitHub secret |
| `retrieve_stream_key_command` | Get the stream key |

### 6. Add GitHub secrets

In your repository → **Settings → Secrets and variables → Actions**:

| Secret | Value |
|---|---|
| `AWS_DEPLOY_ROLE_ARN` | Printed by `bootstrap.sh` |
| `AWS_REGION` | e.g. `eu-west-1` |
| `S3_BUCKET_NAME` | From `terraform output s3_bucket_name` |
| `CLOUDFRONT_DISTRIBUTION_ID` | From `terraform output` |
| `LAMBDA_FUNCTION_NAME` | From `terraform output` |

### 7. Trigger the first deploy

```bash
git tag v0.1.0 && git push origin v0.1.0
```

The `deploy.yml` workflow runs: builds the Lambda zip, syncs the frontend to S3, invalidates CloudFront, publishes a Lambda version, and points the `live` alias at it.

### 8. Configure OBS

In OBS → **Settings → Stream → Custom**:

| Field | Value |
|---|---|
| Server | Paste `ingest_endpoint` from Terraform output |
| Stream Key | Run the `retrieve_stream_key_command` output |

---

## Deployment & Versioning

Every production deploy is triggered by a semver tag:

```bash
git tag v1.2.0 && git push origin v1.2.0
```

The workflow runs three jobs:

1. **prepare** — extracts semver + short SHA, uploads a `VERSION` artifact
2. **deploy-frontend** *(parallel)* — syncs assets to S3 with immutable cache headers, syncs `index.html` with `must-revalidate`, invalidates CloudFront
3. **deploy-lambda** *(parallel)* — builds TypeScript, prunes devDependencies, zips `dist/` + `node_modules/` + `VERSION`, uploads to Lambda, waits for propagation, publishes an immutable version snapshot, updates the `live` alias

Each Lambda version is immutable. Rollback is a single AWS CLI call:

```bash
aws lambda update-alias \
  --function-name streamline \
  --name live \
  --function-version PREVIOUS_VERSION_NUMBER
```

---

## Local Development

```bash
cd lambda
cp .env.example .env     # uses a public HLS test stream
npm install
npm run dev              # starts http server on :3001
```

Then open `frontend/index.html` directly in a browser (no local server needed for the frontend).

The `/api/stream` endpoint returns `status: "idle"` locally because `IVS_CHANNEL_ARN` in `.env.example` is fake — the SDK call hits `ResourceNotFoundException` and falls back to idle gracefully. The player still renders using the public HLS stream set in `IVS_PLAYBACK_URL`.

Available endpoints:

```
GET http://localhost:3001/api/health   → { status, version, region }
GET http://localhost:3001/api/stream   → { playbackUrl, status, dvr }
```

---

## Cost Estimate

All figures are approximate. AWS pricing varies by region.

| Service | At rest | 2h stream, 100 concurrent viewers |
|---|---|---|
| AWS IVS | $0 | ~$1.00 (ingest $0.20/h + output ~$0.80) |
| CloudFront | $0 | ~$0.15 (HLS egress ~1 GB/viewer/h at $0.085/GB) |
| Lambda | $0 | < $0.01 (status polls every 15s, ~3ms execution) |
| S3 | < $0.01/mo (< 1 MB of static assets) | < $0.01 |
| Route 53 | $0.50/mo per hosted zone (if using custom domain) | — |
| ACM | $0 | $0 |
| Secrets Manager | ~$0.40/mo (1 secret) | — |
| **Total** | **< $1/mo** | **~$1.50–2.00 per stream** |

DVR incurs no additional cost — IVS maintains the 4-hour window on its own infrastructure.

---

## License

MIT — see [LICENSE](LICENSE).
