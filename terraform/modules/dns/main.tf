terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      # CloudFront requires ACM certificates issued in us-east-1 regardless of
      # the main region. This alias is passed in from the root module.
      configuration_aliases = [aws.us_east_1]
    }
  }
}

resource "aws_acm_certificate" "this" {
  provider          = aws.us_east_1
  domain_name       = "live.${var.domain_name}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  for_each = {
    for dvo in aws_acm_certificate.this.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id         = var.hosted_zone_id
  name            = each.value.name
  type            = each.value.type
  records         = [each.value.record]
  ttl             = 60
  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "this" {
  provider                = aws.us_east_1
  certificate_arn         = aws_acm_certificate.this.arn
  validation_record_fqdns = [for r in aws_route53_record.cert_validation : r.fqdn]
}

# A alias record pointing live.<domain_name> → CloudFront distribution
resource "aws_route53_record" "live" {
  zone_id = var.hosted_zone_id
  name    = "live.${var.domain_name}"
  type    = "A"

  alias {
    name    = var.cloudfront_domain
    # Z2FDTNDATAQYW2 is the fixed hosted zone ID for all CloudFront distributions.
    zone_id                = "Z2FDTNDATAQYW2"
    evaluate_target_health = false
  }
}
