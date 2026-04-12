variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "Primary AWS region for all resources"
  type        = string
  default     = "eu-west-1"
}

variable "domain_name" {
  description = "Custom domain (e.g. example.com). Leave empty to use the CloudFront default domain."
  type        = string
  default     = ""
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for var.domain_name. Required only when domain_name is set."
  type        = string
  default     = ""
}
