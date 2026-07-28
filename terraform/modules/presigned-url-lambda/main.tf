# =============================================================================
# Presigned URL Generator — Lambda + HTTP API (API Gateway v2)
# =============================================================================
# Accepts POST /upload with filename + metadata, saves a .metadata.json sidecar
# to the landing bucket, and returns a presigned S3 PUT URL.

locals {
  function_name  = "${var.project_name}-presigned-url-${var.environment}"
  expiry_seconds = var.presigned_url_expiry_minutes * 60
}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "lambda" {
  name = "platform-${local.function_name}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Grants CloudWatch Logs write + VPC ENI management
resource "aws_iam_role_policy_attachment" "vpc_execution" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# s3:PutObject covers both the metadata sidecar write and signing the presigned URL
resource "aws_iam_role_policy" "s3" {
  name = "s3-landing-put"
  role = aws_iam_role.lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${var.landing_bucket_arn}/*"
    }]
  })
}

# ── Lambda package ────────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "presigned_url" {
  function_name    = local.function_name
  role             = aws_iam_role.lambda.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 10

  environment {
    variables = {
      LANDING_BUCKET               = var.landing_bucket_id
      PRESIGNED_URL_EXPIRY_SECONDS = tostring(local.expiry_seconds)
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

