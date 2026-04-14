output "cloudfront_url" {
  description = "Viewer URL — share this with your audience"
  value       = module.cloudfront.cloudfront_url
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — GitHub Actions variable CLOUDFRONT_DISTRIBUTION_ID"
  value       = module.cloudfront.distribution_id
}

output "lambda_function_name" {
  description = "Lambda function name — GitHub Actions variable LAMBDA_FUNCTION_NAME"
  value       = module.lambda.function_name
}

output "s3_bucket_name" {
  description = "Frontend S3 bucket name — GitHub Actions variable S3_BUCKET_NAME"
  value       = module.s3.bucket_name
}
