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
    sid       = "IvsGetStream"
    actions   = ["ivs:GetStream"]
    resources = [var.ivs_channel_arn]
  }

  statement {
    sid     = "SecretManagerStreamKey"
    actions = ["secretsmanager:GetSecretValue"]
    # Lambda reads the stream key ARN for future admin use (not the current API).
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

resource "aws_lambda_function" "this" {
  function_name = "streamline-${var.environment}"
  role          = aws_iam_role.lambda.arn

  # nodejs24.x is not yet a managed Lambda runtime. Update when AWS adds it.
  runtime     = "nodejs20.x"
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
      IVS_PLAYBACK_URL = var.ivs_playback_url
      IVS_CHANNEL_ARN  = var.ivs_channel_arn
      IVS_DVR_ENABLED  = "true"
    }
  }
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
