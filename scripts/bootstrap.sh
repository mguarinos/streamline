#!/usr/bin/env bash
set -euo pipefail

# ── Helpers ───────────────────────────────────────────────────────────────────

info()    { echo "  $*"; }
success() { echo "✓ $*"; }
section() { echo ""; echo "── $* ──"; }

# ── 1. Verify prerequisites ───────────────────────────────────────────────────

section "Checking prerequisites"

for cmd in aws terraform jq npm; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not installed." >&2
    exit 1
  fi
  success "$cmd found"
done

# ── 2. Prompt for configuration ───────────────────────────────────────────────

section "Configuration"

read -r -p "AWS region      [eu-west-1]: " AWS_REGION
AWS_REGION="${AWS_REGION:-eu-west-1}"

read -r -p "Environment     [prod]: "       ENVIRONMENT
ENVIRONMENT="${ENVIRONMENT:-prod}"

read -r -p "GitHub org/user []: "           GITHUB_ORG
if [[ -z "$GITHUB_ORG" ]]; then
  echo "Error: GITHUB_ORG is required." >&2
  exit 1
fi

read -r -p "GitHub repo     [streamline]: " GITHUB_REPO
GITHUB_REPO="${GITHUB_REPO:-streamline}"

info "Region:      $AWS_REGION"
info "Environment: $ENVIRONMENT"
info "GitHub:      $GITHUB_ORG/$GITHUB_REPO"

# ── 3. AWS account ID ─────────────────────────────────────────────────────────

section "AWS identity"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
success "Account ID: $ACCOUNT_ID"

# ── 4. S3 state bucket ────────────────────────────────────────────────────────
#
# Locking uses Terraform 1.10+ native S3 locking (use_lockfile = true).
# A .tflock object is written alongside the state file; no DynamoDB needed.
# Versioning is required for the lock file mechanism to work correctly.

section "Terraform state bucket"

STATE_BUCKET="streamline-tfstate-${ENVIRONMENT}-${ACCOUNT_ID}"

if aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null; then
  info "Bucket '$STATE_BUCKET' already exists — skipping creation"
else
  info "Creating bucket '$STATE_BUCKET'..."

  if [[ "$AWS_REGION" == "us-east-1" ]]; then
    # us-east-1 does not accept a LocationConstraint
    aws s3api create-bucket \
      --bucket "$STATE_BUCKET" \
      --region "$AWS_REGION"
  else
    aws s3api create-bucket \
      --bucket "$STATE_BUCKET" \
      --region "$AWS_REGION" \
      --create-bucket-configuration LocationConstraint="$AWS_REGION"
  fi

  aws s3api put-bucket-versioning \
    --bucket "$STATE_BUCKET" \
    --versioning-configuration Status=Enabled

  aws s3api put-bucket-encryption \
    --bucket "$STATE_BUCKET" \
    --server-side-encryption-configuration '{
      "Rules": [{
        "ApplyServerSideEncryptionByDefault": { "SSEAlgorithm": "AES256" }
      }]
    }'

  aws s3api put-public-access-block \
    --bucket "$STATE_BUCKET" \
    --public-access-block-configuration \
      BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

  success "Bucket created"
fi

# ── 5. GitHub OIDC provider ───────────────────────────────────────────────────

section "GitHub OIDC provider"

OIDC_URL="https://token.actions.githubusercontent.com"
OIDC_THUMBPRINT="6938fd4d98bab03faadb97b34396831e3780aea1"

EXISTING_OIDC=$(aws iam list-open-id-connect-providers \
  --query "OpenIDConnectProviderList[?ends_with(Arn, 'oidc-provider/token.actions.githubusercontent.com')].Arn" \
  --output text)

if [[ -n "$EXISTING_OIDC" ]]; then
  info "OIDC provider already exists — skipping creation"
else
  info "Creating OIDC provider..."
  aws iam create-open-id-connect-provider \
    --url "$OIDC_URL" \
    --thumbprint-list "$OIDC_THUMBPRINT" \
    --client-id-list "sts.amazonaws.com"
  success "OIDC provider created"
fi

# ── 6. IAM deploy role ────────────────────────────────────────────────────────

section "IAM deploy role"

ROLE_NAME="streamline-github-deploy-${ENVIRONMENT}"

TRUST_POLICY=$(jq -n \
  --arg account "$ACCOUNT_ID" \
  --arg repo "${GITHUB_ORG}/${GITHUB_REPO}" \
  '{
    Version: "2012-10-17",
    Statement: [{
      Effect: "Allow",
      Principal: {
        Federated: "arn:aws:iam::\($account):oidc-provider/token.actions.githubusercontent.com"
      },
      Action: "sts:AssumeRoleWithWebIdentity",
      Condition: {
        StringEquals: {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        StringLike: {
          "token.actions.githubusercontent.com:sub": "repo:\($repo):ref:refs/tags/v*"
        }
      }
    }]
  }')

INLINE_POLICY=$(jq -n \
  --arg account "$ACCOUNT_ID" \
  '{
    Version: "2012-10-17",
    Statement: [
      {
        Sid: "S3Frontend",
        Effect: "Allow",
        Action: ["s3:GetObject","s3:PutObject","s3:DeleteObject","s3:ListBucket"],
        Resource: [
          "arn:aws:s3:::streamline-frontend-*",
          "arn:aws:s3:::streamline-frontend-*/*",
          "arn:aws:s3:::streamline-tfstate-*",
          "arn:aws:s3:::streamline-tfstate-*/*"
        ]
      },
      {
        Sid: "Lambda",
        Effect: "Allow",
        Action: [
          "lambda:UpdateFunctionCode",
          "lambda:PublishVersion",
          "lambda:UpdateAlias",
          "lambda:GetFunction",
          "lambda:ListAliases",
          "lambda:GetFunctionUrlConfig"
        ],
        Resource: "arn:aws:lambda:*:*:function:streamline-*"
      },
      {
        Sid: "CloudFront",
        Effect: "Allow",
        Action: "cloudfront:CreateInvalidation",
        Resource: "*"
      },
      {
        Sid: "IamReadOnly",
        Effect: "Allow",
        Action: ["iam:GetRole","iam:GetRolePolicy"],
        Resource: "*"
      }
    ]
  }')

if aws iam get-role --role-name "$ROLE_NAME" &>/dev/null; then
  info "Role '$ROLE_NAME' already exists — skipping creation"
else
  info "Creating IAM role '$ROLE_NAME'..."
  aws iam create-role \
    --role-name "$ROLE_NAME" \
    --assume-role-policy-document "$TRUST_POLICY"
  success "Role created"
fi

info "Updating inline policy..."
aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name "streamline-deploy-${ENVIRONMENT}" \
  --policy-document "$INLINE_POLICY"
success "Inline policy applied"

# ── 7. Write terraform/backend.hcl ───────────────────────────────────────────

section "Writing terraform/backend.hcl"

BACKEND_FILE="$(dirname "$0")/../terraform/backend.hcl"

cat > "$BACKEND_FILE" <<EOF
bucket       = "streamline-tfstate-${ENVIRONMENT}-${ACCOUNT_ID}"
key          = "streamline/${ENVIRONMENT}/terraform.tfstate"
region       = "${AWS_REGION}"
encrypt      = true
use_lockfile = true
EOF

success "Written to terraform/backend.hcl"

# ── 8. Build Lambda zip ───────────────────────────────────────────────────────
#
# Produces lambda/function.zip so the first terraform apply can provision the
# function without a separate CI run.

section "Building Lambda deployment package"

LAMBDA_DIR="$(dirname "$0")/../lambda"

(cd "$LAMBDA_DIR" && npm ci && npm run package)

success "lambda/function.zip created"

# ── 9. Summary ────────────────────────────────────────────────────────────────

echo ""
echo "✓ Bootstrap complete"
echo ""
echo "Next steps:"
echo "  1. cd terraform"
echo "  2. terraform init -backend-config=../terraform/backend.hcl"
echo "  3. terraform plan -var=environment=${ENVIRONMENT} -var=aws_region=${AWS_REGION}"
echo "  4. terraform apply"
echo "  5. Add these GitHub secrets to your repo:"
echo "       AWS_DEPLOY_ROLE_ARN: arn:aws:iam::${ACCOUNT_ID}:role/streamline-github-deploy-${ENVIRONMENT}"
echo "       AWS_REGION: ${AWS_REGION}"
echo "       S3_BUCKET_NAME: (from terraform output s3_bucket_name)"
echo "       CLOUDFRONT_DISTRIBUTION_ID: (from terraform output)"
echo "       LAMBDA_FUNCTION_NAME: (from terraform output)"
echo ""
echo "  6. git tag v0.1.0 && git push origin v0.1.0"
