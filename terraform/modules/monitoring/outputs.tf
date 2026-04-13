output "health_check_id" {
  description = "Route 53 health check ID for the /api/health endpoint"
  value       = aws_route53_health_check.api.id
}

output "alarms_sns_arn" {
  description = "SNS topic ARN for Lambda alarms (main region)"
  value       = aws_sns_topic.alarms.arn
}

output "alarms_us_east_1_sns_arn" {
  description = "SNS topic ARN for CloudFront alarms (us-east-1)"
  value       = aws_sns_topic.alarms_us_east_1.arn
}
