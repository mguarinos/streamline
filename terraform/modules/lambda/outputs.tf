output "function_name" {
  description = "Lambda function name — used in CloudWatch alarm dimensions"
  value       = aws_lambda_function.this.function_name
}

output "function_url" {
  description = "Lambda function URL (HTTPS endpoint on the live alias)"
  value       = aws_lambda_function_url.live.function_url
}
