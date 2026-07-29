# =============================================================================
# Audit Lambda — writes document audit records to DynamoDB on processed bucket
# =============================================================================
# Triggered by S3 ObjectCreated on the processed bucket.
# .metadata.json events → upsert with all metadata fields.
# All other events → upsert with filename + timestamps only.

locals {
  function_name = "${var.project_name}-document-audit-trail-${var.environment}"
}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "audit" {
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

resource "aws_iam_role_policy_attachment" "vpc_execution" {
  role       = aws_iam_role.audit.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "s3_read" {
  name = "s3-processed-read"
  role = aws_iam_role.audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:GetObject"]
      Resource = "${var.processed_bucket_arn}/*"
    }]
  })
}

resource "aws_iam_role_policy" "dynamodb_audit" {
  name = "dynamodb-audit-trail"
  role = aws_iam_role.audit.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:UpdateItem"]
      Resource = var.audit_table_arn
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

resource "aws_lambda_function" "audit" {
  function_name    = local.function_name
  role             = aws_iam_role.audit.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 30

  environment {
    variables = {
      PROCESSED_BUCKET = var.processed_bucket_id
      AUDIT_TABLE      = var.audit_table_name
    }
  }

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [var.security_group_id]
  }
}

# ── S3 trigger ────────────────────────────────────────────────────────────────

resource "aws_lambda_permission" "s3" {
  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.audit.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.processed_bucket_arn
}

resource "aws_s3_bucket_notification" "processed" {
  bucket = var.processed_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.audit.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3]
}
