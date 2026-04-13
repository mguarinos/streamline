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

# Used by the dns module (ACM certificates for CloudFront must be in us-east-1)
# and by the monitoring module (CloudFront metrics are only in us-east-1).
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
  ivs_stream_key_arn = module.ivs.stream_key_arn
}

# ── S3 ────────────────────────────────────────────────────────────────────────

module "s3" {
  source      = "./modules/s3"
  environment = var.environment
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

# ── Lambda permission — CloudFront OAC ───────────────────────────────────────
#
# Placed here rather than inside the lambda module because both
# module.lambda (function name / alias) and module.cloudfront (distribution
# ARN) are needed. Putting it here breaks the circular dependency the same
# way the S3 bucket policy does.

resource "aws_lambda_permission" "cloudfront_invoke" {
  statement_id  = "AllowCloudFrontInvoke"
  action        = "lambda:InvokeFunction"
  function_name = module.lambda.function_name
  qualifier     = "live"
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.distribution_arn
}

resource "aws_lambda_permission" "cloudfront_invoke_url" {
  statement_id  = "AllowCloudFrontInvokeUrl"
  action        = "lambda:InvokeFunctionUrl"
  function_name = module.lambda.function_name
  qualifier     = "live"
  principal     = "cloudfront.amazonaws.com"
  source_arn    = module.cloudfront.distribution_arn
}

# ── S3 bucket policy ──────────────────────────────────────────────────────────
#
# Grants the CloudFront OAC read access to the frontend bucket.
# Placed here rather than inside the s3 module so that the s3 → cloudfront →
# s3 (bucket policy) chain resolves in a single terraform apply without the
# need for -target workarounds.

data "aws_iam_policy_document" "s3_oac" {
  statement {
    sid       = "AllowCloudFrontOAC"
    actions   = ["s3:GetObject"]
    resources = ["${module.s3.bucket_arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      values   = [module.cloudfront.distribution_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = module.s3.bucket_name
  policy = data.aws_iam_policy_document.s3_oac.json
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

# ── Monitoring ────────────────────────────────────────────────────────────────

module "monitoring" {
  source = "./modules/monitoring"

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  environment                = var.environment
  lambda_function_name       = module.lambda.function_name
  cloudfront_distribution_id = module.cloudfront.distribution_id
  cloudfront_domain          = module.cloudfront.distribution_domain
  alarm_email                = var.alarm_email
}
