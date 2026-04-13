locals {
  # Extract hostname from URLs.
  # Lambda function URL:  https://<id>.lambda-url.<region>.on.aws/
  # IVS playback URL:     https://<id>.cloudfront.net/ivs/v1/.../master.m3u8
  lambda_hostname = regex("https://([^/]+)", var.lambda_function_url)[0]
  ivs_hostname    = regex("https://([^/]+)", var.ivs_playback_url)[0]
}

# Custom cache policy for HLS segments.
# Short TTL because HLS segments are short-lived; DVR segments are served
# directly from IVS infrastructure so we keep caching light.
# Query strings are included in the cache key and forwarded — IVS uses
# query params for DVR segment requests.
# OAC for the Lambda origin — CloudFront signs every request with SigV4.
# Lambda URL uses authorization_type = "AWS_IAM" and the resource-based
# policy only allows cloudfront.amazonaws.com with this distribution's ARN.
resource "aws_cloudfront_origin_access_control" "lambda" {
  name                              = "streamline-lambda-${var.environment}"
  description                       = "SigV4 signing for Lambda Function URL origin"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_cache_policy" "hls" {
  name        = "streamline-hls-${var.environment}"
  min_ttl     = 1
  default_ttl = 5
  max_ttl     = 10

  parameters_in_cache_key_and_forwarded_to_origin {
    cookies_config {
      cookie_behavior = "none"
    }
    headers_config {
      header_behavior = "none"
    }
    query_strings_config {
      query_string_behavior = "all"
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled             = true
  comment             = "streamline-${var.environment}"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  http_version        = "http2and3"
  aliases             = var.domain_name != "" ? ["live.${var.domain_name}"] : []

  # ── Origin 1: S3 frontend ─────────────────────────────────────────────────
  origin {
    domain_name              = var.s3_bucket_regional_domain
    origin_id                = "s3-frontend"
    origin_access_control_id = var.s3_oac_id
  }

  # ── Origin 2: Lambda API ──────────────────────────────────────────────────
  origin {
    domain_name              = local.lambda_hostname
    origin_id                = "lambda-api"
    origin_access_control_id = aws_cloudfront_origin_access_control.lambda.id

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── Origin 3: IVS playback ────────────────────────────────────────────────
  origin {
    domain_name = local.ivs_hostname
    origin_id   = "ivs-playback"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "https-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  # ── Cache behaviour: /api/* → Lambda ─────────────────────────────────────
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    target_origin_id = "lambda-api"

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD", "OPTIONS"]
    cached_methods         = ["GET", "HEAD"]
    compress               = false

    # CachingDisabled — API responses must never be cached
    cache_policy_id = "4135ea2d-6df8-44a3-9df3-4b5a84be39ad"
    # AllViewerExceptHostHeader — forward all request headers except Host
    origin_request_policy_id = "b689b0a8-53d0-40ab-baf2-68738e2966ac"
  }

  # ── Cache behaviour: /hls/* → IVS playback ───────────────────────────────
  ordered_cache_behavior {
    path_pattern     = "/hls/*"
    target_origin_id = "ivs-playback"

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    cache_policy_id = aws_cloudfront_cache_policy.hls.id
  }

  # ── Default behaviour: /* → S3 frontend ──────────────────────────────────
  default_cache_behavior {
    target_origin_id = "s3-frontend"

    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    # CachingOptimized — suitable for static assets
    cache_policy_id = "658327ea-f89d-4fab-a63d-7e88639e58f6"
  }

  # ── TLS / viewer certificate ──────────────────────────────────────────────
  viewer_certificate {
    # When domain_name is empty: use the default *.cloudfront.net certificate.
    # When domain_name is set:   use the ACM certificate from the dns module.
    cloudfront_default_certificate = var.domain_name == ""
    acm_certificate_arn            = var.domain_name != "" ? var.acm_certificate_arn : null
    ssl_support_method             = var.domain_name != "" ? "sni-only" : null
    minimum_protocol_version       = var.domain_name != "" ? "TLSv1.2_2021" : null
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
}
