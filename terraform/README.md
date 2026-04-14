# Terraform — root module

Wires together the six child modules and manages the two cross-module resources that would otherwise create circular dependencies: the S3 bucket policy (needs both `s3` and `cloudfront`) and the CloudFront → Lambda permission (needs both `lambda` and `cloudfront`).

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
