output "ingest_endpoint" {
  description = "RTMP ingest URL — paste into OBS/Larix as Server"
  value       = module.ivs.ingest_endpoint
}

output "stream_key_arn" {
  description = "Secrets Manager ARN for the IVS stream key"
  value       = module.ivs.stream_key_arn
}

output "cloudfront_url" {
  description = "Viewer URL (CloudFront distribution)"
  value       = module.cloudfront.cloudfront_url
}

output "lambda_function_url" {
  description = "Direct Lambda function URL (for debugging — bypasses CloudFront)"
  value       = module.lambda.function_url
}

output "ivs_playback_url" {
  description = "Raw IVS playback URL (for debugging — bypasses CloudFront)"
  value       = module.ivs.playback_url
}

output "s3_bucket_name" {
  description = "Frontend S3 bucket name — used in GitHub Actions S3 sync"
  value       = module.s3.bucket_name
}

output "retrieve_stream_key_command" {
  description = "CLI command to retrieve the stream key from Secrets Manager"
  value       = "aws secretsmanager get-secret-value --secret-id streamline/${var.environment}/stream-key --query SecretString --output text"
}
