# Module: dns

Provisions an ACM certificate in `us-east-1` (required for CloudFront), validates it via Route 53 DNS records, and creates an A/AAAA alias record pointing the custom domain at the CloudFront distribution. Only instantiated when `domain_name` and `hosted_zone_id` are set.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
