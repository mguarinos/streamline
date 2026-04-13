terraform {
  required_providers {
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

resource "random_id" "bucket_suffix" {
  byte_length = 4
}

resource "aws_s3_bucket" "frontend" {
  bucket = "streamline-frontend-${var.environment}-${random_id.bucket_suffix.hex}"
}

resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# OAC is created here because it is logically owned by the S3 origin.
# The CloudFront distribution references it by ID (passed from this module's output).
resource "aws_cloudfront_origin_access_control" "s3" {
  name                              = "streamline-s3-${var.environment}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}
