# =============================================================================
# Ingest Lambda — moves documents from landing to processed bucket on upload
# =============================================================================
# Triggered by S3 ObjectCreated events on the landing bucket.
# Copies both the document and its .metadata.json sidecar to the processed
# bucket, then deletes the originals. Future text transformation goes here.

locals {
  function_name = "${var.project_name}-ingest-${var.environment}"
}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "ingest" {
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
  role       = aws_iam_role.ingest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "s3" {
  name = "s3-landing-processed"
  role = aws_iam_role.ingest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:HeadObject", "s3:DeleteObject"]
        Resource = "${var.landing_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${var.processed_bucket_arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob"]
        Resource = "arn:aws:bedrock:*:*:knowledge-base/${var.kb_id}"
      }
    ]
  })
}

# ── Lambda package ────────────────────────────────────────────────────────────

data "archive_file" "lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/handler.py"
  output_path = "${path.module}/lambda/handler.zip"
}

# ── Lambda function ───────────────────────────────────────────────────────────

resource "aws_lambda_function" "ingest" {
  function_name    = local.function_name
  role             = aws_iam_role.ingest.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      LANDING_BUCKET    = var.landing_bucket_id
      PROCESSED_BUCKET  = var.processed_bucket_id
      KB_ID             = var.kb_id
      KB_DATA_SOURCE_ID = var.kb_data_source_id
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
  function_name = aws_lambda_function.ingest.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.landing_bucket_arn
}

resource "aws_s3_bucket_notification" "landing" {
  bucket = var.landing_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.ingest.arn
    events              = ["s3:ObjectCreated:*"]
  }

  depends_on = [aws_lambda_permission.s3]
}
