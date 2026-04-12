variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
}

variable "cloudfront_distribution_arn" {
  description = "ARN of the CloudFront distribution allowed to read from this bucket. Empty string skips bucket policy creation (used during bootstrap)."
  type        = string
  default     = ""
}
