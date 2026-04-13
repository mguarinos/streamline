output "certificate_arn" {
  description = "Validated ACM certificate ARN (us-east-1) — passed to the CloudFront module"
  value       = aws_acm_certificate_validation.this.certificate_arn
}
