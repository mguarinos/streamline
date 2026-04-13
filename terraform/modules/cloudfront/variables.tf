variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
}

variable "s3_bucket_regional_domain" {
  description = "S3 bucket regional domain name (from s3 module)"
  type        = string
}

variable "s3_oac_id" {
  description = "CloudFront Origin Access Control ID for the S3 origin (from s3 module)"
  type        = string
}

variable "lambda_function_url" {
  description = "Lambda function URL — hostname is extracted and used as the API origin"
  type        = string
}

variable "ivs_playback_url" {
  description = "IVS playback URL — hostname is extracted and used as the HLS origin"
  type        = string
}

variable "domain_name" {
  description = "Custom domain name. When non-empty, CloudFront serves live.<domain_name> with the provided ACM certificate."
  type        = string
  default     = ""
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN (us-east-1) for the custom domain. Required when domain_name is set."
  type        = string
  default     = ""
}
