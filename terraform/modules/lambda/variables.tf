variable "environment" {
  description = "Deployment environment (e.g. prod, staging)"
  type        = string
}

variable "ivs_playback_url" {
  description = "Full IVS playback URL injected as Lambda environment variable"
  type        = string
}

variable "ivs_stream_key_arn" {
  description = "Secrets Manager ARN for the IVS stream key — granted in Lambda IAM policy"
  type        = string
}

variable "function_zip_path" {
  description = "Path to the Lambda deployment zip, relative to the Terraform working directory"
  type        = string
  default     = "../lambda/function.zip"
}
