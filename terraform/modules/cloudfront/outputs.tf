output "distribution_id" {
  description = "CloudFront distribution ID — used in GitHub Actions cache invalidation"
  value       = aws_cloudfront_distribution.this.id
}

output "distribution_domain" {
  description = "CloudFront distribution domain name (e.g. d1234abcd.cloudfront.net)"
  value       = aws_cloudfront_distribution.this.domain_name
}

output "cloudfront_url" {
  description = "Full viewer URL"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "distribution_arn" {
  description = "CloudFront distribution ARN — used in the S3 bucket policy"
  value       = aws_cloudfront_distribution.this.arn
}
