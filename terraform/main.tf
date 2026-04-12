provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "streamline"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# Used exclusively by the dns module — ACM certificates for CloudFront
# must be issued in us-east-1 regardless of the main region.
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"

  default_tags {
    tags = {
      Project     = "streamline"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# ── IVS ──────────────────────────────────────────────────────────────────────

module "ivs" {
  source      = "./modules/ivs"
  environment = var.environment
}

# ── Lambda ────────────────────────────────────────────────────────────────────

module "lambda" {
  source             = "./modules/lambda"
  environment        = var.environment
  ivs_playback_url   = module.ivs.playback_url
  ivs_channel_arn    = module.ivs.channel_arn
  ivs_stream_key_arn = module.ivs.stream_key_arn
}

# ── S3 ────────────────────────────────────────────────────────────────────────
#
# NOTE — two-step bootstrap required on first deploy:
#
#   The s3 module bucket policy needs the CloudFront distribution ARN, and the
#   cloudfront module needs the S3 bucket domain and OAC ID. Terraform cannot
#   resolve this in a single pass on the very first apply.
#
#   Bootstrap sequence:
#     1. terraform apply -target=module.ivs -target=module.lambda -target=module.s3
#     2. terraform apply   (creates CloudFront, then applies the bucket policy)
#
#   Subsequent applies work in one pass — Terraform already knows all ARNs.

module "s3" {
  source                      = "./modules/s3"
  environment                 = var.environment
  cloudfront_distribution_arn = module.cloudfront.distribution_arn
}

# ── CloudFront ────────────────────────────────────────────────────────────────

module "cloudfront" {
  source                    = "./modules/cloudfront"
  environment               = var.environment
  s3_bucket_regional_domain = module.s3.bucket_regional_domain
  s3_oac_id                 = module.s3.oac_id
  lambda_function_url       = module.lambda.function_url
  ivs_playback_url          = module.ivs.playback_url
  domain_name               = var.domain_name
  acm_certificate_arn       = var.domain_name != "" ? module.dns[0].certificate_arn : ""
}

# ── DNS (optional) ────────────────────────────────────────────────────────────

module "dns" {
  count  = var.domain_name != "" ? 1 : 0
  source = "./modules/dns"

  providers = {
    aws.us_east_1 = aws.us_east_1
  }

  domain_name       = var.domain_name
  cloudfront_domain = module.cloudfront.distribution_domain
  hosted_zone_id    = var.hosted_zone_id
}
