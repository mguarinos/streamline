terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 5.0"
      configuration_aliases = [aws.us_east_1]
    }
  }
}

# ── SNS topics ────────────────────────────────────────────────────────────────
#
# Two topics: one in the main region (Lambda alarms) and one in us-east-1
# (CloudFront alarms — CloudFront metrics are only emitted to us-east-1).

resource "aws_sns_topic" "alarms" {
  name = "streamline-alarms-${var.environment}"
}

resource "aws_sns_topic" "alarms_us_east_1" {
  provider = aws.us_east_1
  name     = "streamline-alarms-${var.environment}"
}

resource "aws_sns_topic_subscription" "email" {
  count     = var.alarm_email != "" ? 1 : 0
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

resource "aws_sns_topic_subscription" "email_us_east_1" {
  count     = var.alarm_email != "" ? 1 : 0
  provider  = aws.us_east_1
  topic_arn = aws_sns_topic.alarms_us_east_1.arn
  protocol  = "email"
  endpoint  = var.alarm_email
}

# ── Lambda alarms ─────────────────────────────────────────────────────────────

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  alarm_name          = "streamline-${var.environment}-lambda-errors"
  alarm_description   = "Lambda error count exceeds threshold — investigate immediately"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
    Resource     = "${var.lambda_function_name}:live"
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_p99" {
  alarm_name          = "streamline-${var.environment}-lambda-p99-duration"
  alarm_description   = "Lambda p99 duration exceeds 5 seconds — check for cold starts or slow SSM calls"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = 60
  extended_statistic  = "p99"
  threshold           = 5000
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]
  ok_actions          = [aws_sns_topic.alarms.arn]

  dimensions = {
    FunctionName = var.lambda_function_name
    Resource     = "${var.lambda_function_name}:live"
  }
}

# ── CloudFront alarms (us-east-1) ─────────────────────────────────────────────
#
# CloudFront metrics are only published to us-east-1 regardless of the
# distribution's origin region.

resource "aws_cloudwatch_metric_alarm" "cloudfront_5xx" {
  provider            = aws.us_east_1
  alarm_name          = "streamline-${var.environment}-cloudfront-5xx"
  alarm_description   = "CloudFront 5xx error rate exceeds 5% — check Lambda and S3 origins"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5xxErrorRate"
  namespace           = "AWS/CloudFront"
  period              = 60
  statistic           = "Average"
  threshold           = 5
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms_us_east_1.arn]
  ok_actions          = [aws_sns_topic.alarms_us_east_1.arn]

  dimensions = {
    DistributionId = var.cloudfront_distribution_id
    Region         = "Global"
  }
}

# ── Route 53 health check ─────────────────────────────────────────────────────

resource "aws_route53_health_check" "api" {
  fqdn              = var.cloudfront_domain
  port              = 443
  type              = "HTTPS"
  resource_path     = "/api/health"
  failure_threshold = 3
  request_interval  = 30

  tags = {
    Name = "streamline-${var.environment}-api-health"
  }
}
