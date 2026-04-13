data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda" {
  name               = "streamline-lambda-${var.environment}"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

data "aws_iam_policy_document" "lambda_custom" {
  statement {
    sid    = "SsmStreamState"
    actions = ["ssm:GetParameter", "ssm:PutParameter"]
    resources = [aws_ssm_parameter.stream_state.arn]
  }

  statement {
    sid     = "SecretManagerStreamKey"
    actions = ["secretsmanager:GetSecretValue"]
    resources = [var.ivs_stream_key_arn]
  }
}

resource "aws_iam_policy" "lambda_custom" {
  name   = "streamline-lambda-${var.environment}"
  policy = data.aws_iam_policy_document.lambda_custom.json
}

resource "aws_iam_role_policy_attachment" "lambda_custom" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda_custom.arn
}

# ── CloudWatch log group ──────────────────────────────────────────────────────

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/streamline-${var.environment}"
  retention_in_days = 30
}

# ── SSM parameter — stream state source of truth ─────────────────────────────
#
# EventBridge triggers the Lambda state handler on IVS stream state changes.
# The handler writes { status, updatedAt } here. The /api/stream handler reads
# this parameter (with a 10s module-level cache) instead of polling IVS directly.

resource "aws_ssm_parameter" "stream_state" {
  name  = "/streamline/${var.environment}/stream-state"
  type  = "String"
  value = jsonencode({ status = "idle", updatedAt = "1970-01-01T00:00:00.000Z" })

  lifecycle {
    # Lambda owns the value after first creation — ignore Terraform drift.
    ignore_changes = [value]
  }
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "this" {
  function_name = "streamline-${var.environment}"
  role          = aws_iam_role.lambda.arn

  runtime     = "nodejs22.x"
  handler     = "dist/index.handler"
  memory_size = 256
  timeout     = 10

  # Path is relative to the Terraform working directory (terraform/).
  # Terraform provisions the function; code updates are owned by CI via
  # update-function-code + publish-version. source_code_hash is intentionally
  # omitted to avoid plan-time failures when the zip doesn't exist yet.
  filename = var.function_zip_path

  environment {
    variables = {
      IVS_PLAYBACK_URL       = var.ivs_playback_url
      IVS_DVR_ENABLED        = "true"
      SSM_STREAM_STATE_PARAM = aws_ssm_parameter.stream_state.name
      ORIGIN_VERIFY_SECRET   = var.origin_verify_secret
      # AWS_REGION is set automatically by the Lambda runtime — do not override.
    }
  }

  depends_on = [aws_cloudwatch_log_group.lambda]
}

# CloudFront and all external references target this alias, never $LATEST.
# GitHub Actions updates the alias pointer on every deploy.
resource "aws_lambda_alias" "live" {
  name             = "live"
  function_name    = aws_lambda_function.this.function_name
  function_version = "$LATEST"
}

resource "aws_lambda_function_url" "live" {
  function_name      = aws_lambda_function.this.function_name
  qualifier          = aws_lambda_alias.live.name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET", "OPTIONS"]
  }
}

# ── EventBridge — IVS stream state change events ──────────────────────────────

resource "aws_cloudwatch_event_rule" "ivs_stream_state" {
  name        = "streamline-ivs-state-${var.environment}"
  description = "IVS stream start / end / failure → Lambda state handler"

  event_pattern = jsonencode({
    source      = ["aws.ivs"]
    detail-type = ["IVS Stream State Change"]
  })
}

resource "aws_cloudwatch_event_target" "lambda" {
  rule      = aws_cloudwatch_event_rule.ivs_stream_state.name
  target_id = "streamline-lambda-${var.environment}"
  arn       = aws_lambda_alias.live.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.this.function_name
  qualifier     = aws_lambda_alias.live.name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ivs_stream_state.arn
}
