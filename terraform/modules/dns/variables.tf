variable "domain_name" {
  description = "Base domain name (e.g. example.com). The record live.<domain_name> is created."
  type        = string
}

variable "cloudfront_domain" {
  description = "CloudFront distribution domain name — used as the A alias target"
  type        = string
}

variable "hosted_zone_id" {
  description = "Route 53 hosted zone ID for var.domain_name"
  type        = string
}
