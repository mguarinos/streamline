output "function_name" {
  description = "Lambda function name — used in CloudWatch alarm dimensions"
  value       = aws_lambda_function.this.function_name
}

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

output "ssm_param_name" {
  description = "SSM parameter name for stream state — written by EventBridge handler"
  value       = aws_ssm_parameter.stream_state.name
}
