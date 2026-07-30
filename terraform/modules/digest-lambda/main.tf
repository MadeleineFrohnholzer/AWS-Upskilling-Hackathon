# =============================================================================
# Digest Lambda — weekly document audit email via SES
# =============================================================================
# EventBridge fires every Monday 06:00 UTC (07:00 CET).
# Lambda scans the document-audit-trail table, builds two Industry x Client
# count tables (new vs. updated this week), and sends an HTML email via SES.
# No VPC — SES has no VPC endpoint and requires internet access.

# ── SES email identity ────────────────────────────────────────────────────────

resource "aws_ses_email_identity" "sender" {
  email = var.sender_email
}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "digest" {
  name = "platform-weekly-audit-digest-mailer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "basic_execution" {
  role       = aws_iam_role.digest.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "dynamodb_scan" {
  name = "dynamodb-audit-scan"
  role = aws_iam_role.digest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["dynamodb:Query"]
      Resource = [
        var.audit_table_arn,
        "${var.audit_table_arn}/index/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "ses_send" {
  name = "ses-send-email"
  role = aws_iam_role.digest.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ses:SendEmail"]
      Resource = aws_ses_email_identity.sender.arn
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

resource "aws_lambda_function" "digest" {
  function_name    = "weekly-audit-digest-mailer"
  role             = aws_iam_role.digest.arn
  handler          = "handler.handler"
  runtime          = "python3.12"
  filename         = data.archive_file.lambda.output_path
  source_code_hash = data.archive_file.lambda.output_base64sha256
  timeout          = 60

  environment {
    variables = {
      AUDIT_TABLE     = var.audit_table_name
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.sender_email
    }
  }
}

# ── EventBridge schedule — Monday 06:00 UTC (07:00 CET) ──────────────────────

resource "aws_cloudwatch_event_rule" "monday_morning" {
  name                = "weekly-digest-monday-morning"
  description         = "Triggers the weekly document digest every Monday at 07:00 CET"
  schedule_expression = "cron(0 6 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "digest_lambda" {
  rule = aws_cloudwatch_event_rule.monday_morning.name
  arn  = aws_lambda_function.digest.arn
}

resource "aws_lambda_permission" "eventbridge" {
  statement_id  = "AllowEventBridgeInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.digest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monday_morning.arn
}
