variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
}

variable "lambda_function_name" {
  description = "Lambda function name — used in CloudWatch alarm dimensions"
  type        = string
}

variable "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — used in CloudWatch alarm dimensions"
  type        = string
}

variable "cloudfront_domain" {
  description = "CloudFront distribution domain (e.g. d1234abcd.cloudfront.net) — used in Route 53 health check"
  type        = string
}

variable "alarm_email" {
  description = "Email address for alarm notifications. Leave empty to create SNS topics without subscriptions."
  type        = string
  default     = ""
}
