# Module: monitoring

Provisions CloudWatch alarms for Lambda errors/throttles and CloudFront 5xx rates, with SNS topics for alerting. A Route 53 health check on `/api/health` is also created. Only instantiated when `alarm_email` is set.

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->
