output "function_arn" {
  description = "Lambda function ARN"
  value       = aws_lambda_function.this.arn
}

output "alias_arn" {
  description = "Lambda alias ARN (live) — used by CloudFront as the API origin"
  value       = aws_lambda_alias.live.arn
}

output "invoke_arn" {
  description = "Lambda alias invoke ARN"
  value       = aws_lambda_alias.live.invoke_arn
}

output "function_url" {
  description = "Lambda function URL (HTTPS endpoint on the live alias)"
  value       = aws_lambda_function_url.live.function_url
}
