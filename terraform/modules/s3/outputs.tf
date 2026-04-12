output "bucket_name" {
  description = "S3 bucket name — used in GitHub Actions S3 sync"
  value       = aws_s3_bucket.frontend.bucket
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.frontend.arn
}

output "bucket_regional_domain" {
  description = "S3 bucket regional domain name — used as CloudFront S3 origin"
  value       = aws_s3_bucket.frontend.bucket_regional_domain_name
}

output "oac_id" {
  description = "CloudFront Origin Access Control ID — passed to the CloudFront module"
  value       = aws_cloudfront_origin_access_control.s3.id
}
