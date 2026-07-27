# =============================================================================
# Team 0 — Foundation / Ingestion (Milestone 0)
# =============================================================================
# Owns: S3, Lambda, API Gateway, Bedrock KB, DynamoDB, EventBridge, SES, CloudWatch

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }

  backend "s3" {
    bucket         = "hackathon-tf-state-064453091991"
    key            = "team0/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hackathon-tf-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Team        = "team0-ingestion"
      ManagedBy   = "terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Read shared infrastructure outputs
# -----------------------------------------------------------------------------
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-064453091991"
    key    = "shared/terraform.tfstate"
    region = "eu-central-1"
  }
}

locals {
  vpc_id                   = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids       = data.terraform_remote_state.shared.outputs.private_subnet_ids
  lambda_security_group_id = data.terraform_remote_state.shared.outputs.lambda_security_group_id
}

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

# =============================================================================
# M0-01 — Storage Module + DynamoDB Documents Table
# =============================================================================

module "storage" {
  source = "../modules/storage"

  project_name = var.project_name
  environment  = var.environment
}

resource "aws_dynamodb_table" "documents" {
  name         = "${var.project_name}-documents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  attribute {
    name = "industry"
    type = "S"
  }

  attribute {
    name = "uploaded_at"
    type = "S"
  }

  global_secondary_index {
    name            = "industry-uploaded_at-index"
    hash_key        = "industry"
    range_key       = "uploaded_at"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = { Name = "${var.project_name}-documents" }
}

# Allow Bedrock KB service to read the processed bucket
resource "aws_s3_bucket_policy" "processed_bedrock" {
  bucket = module.storage.processed_bucket_id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "BedrockKBRead"
      Effect = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = ["s3:GetObject", "s3:ListBucket"]
      Resource  = [
        module.storage.processed_bucket_arn,
        "${module.storage.processed_bucket_arn}/*"
      ]
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

# =============================================================================
# M0-02 — Shared Lambda IAM Role
# =============================================================================

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

resource "aws_iam_role_policy" "lambda_permissions" {
  name = "team1-lambda-permissions"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:GetObject", "s3:CopyObject"]
        Resource = [
          "${module.storage.landing_bucket_arn}/*",
          "${module.storage.processed_bucket_arn}/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = [module.storage.landing_bucket_arn, module.storage.processed_bucket_arn]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:GetItem", "dynamodb:UpdateItem",
                    "dynamodb:Scan", "dynamodb:Query"]
        Resource = [aws_dynamodb_table.documents.arn,
                    "${aws_dynamodb_table.documents.arn}/index/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob", "bedrock:GetKnowledgeBase"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

# =============================================================================
# M0-02 — Lambda: Presigned URL Generator
# =============================================================================

data "archive_file" "presign" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/presigned_url"
  output_path = "${path.module}/lambda/presigned_url.zip"
}

resource "aws_lambda_function" "presign" {
  function_name    = "${var.project_name}-presign-url"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.presign.output_path
  source_code_hash = data.archive_file.presign.output_base64sha256

  environment {
    variables = {
      LANDING_BUCKET  = module.storage.landing_bucket_id
      DOCUMENTS_TABLE = aws_dynamodb_table.documents.name
    }
  }

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_security_group_id]
  }
}

resource "aws_cloudwatch_log_group" "presign" {
  name              = "/aws/lambda/${aws_lambda_function.presign.function_name}"
  retention_in_days = 7
}

# =============================================================================
# M0-02 — API Gateway: Private REST API
# =============================================================================

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "Internal document ingestion API (VPC-only)"

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [data.terraform_remote_state.shared.outputs.endpoint_ids["execute-api"]]
  }
}

resource "aws_api_gateway_rest_api_policy" "vpce_only" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "execute-api:Invoke"
      Resource  = "${aws_api_gateway_rest_api.main.execution_arn}/*"
      Condition = {
        StringEquals = { "aws:SourceVpc" = local.vpc_id }
      }
    }]
  })
}

resource "aws_api_gateway_resource" "upload_url" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "upload-url"
}

resource "aws_api_gateway_method" "upload_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload_url.id
  http_method   = "POST"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "upload_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.upload_url.id
  http_method             = aws_api_gateway_method.upload_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presign.invoke_arn
}

resource "aws_lambda_permission" "api_gw_presign" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presign.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload_url.id,
      aws_api_gateway_method.upload_post.id,
      aws_api_gateway_integration.upload_post.id,
    ]))
  }

  lifecycle { create_before_destroy = true }

  depends_on = [aws_api_gateway_integration.upload_post]
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
}

# =============================================================================
# M0-03 — Lambda: Metadata Sidecar + S3 Event Trigger
# =============================================================================

data "archive_file" "sidecar" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/sidecar"
  output_path = "${path.module}/lambda/sidecar.zip"
}

resource "aws_lambda_function" "sidecar" {
  function_name    = "${var.project_name}-metadata-sidecar"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.sidecar.output_path
  source_code_hash = data.archive_file.sidecar.output_base64sha256

  environment {
    variables = {
      PROCESSED_BUCKET = module.storage.processed_bucket_id
      DOCUMENTS_TABLE  = aws_dynamodb_table.documents.name
      BEDROCK_KB_ID    = ""  # filled after M0-04 apply
      BEDROCK_DS_ID    = ""  # filled after M0-04 apply
    }
  }

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_security_group_id]
  }
}

resource "aws_cloudwatch_log_group" "sidecar" {
  name              = "/aws/lambda/${aws_lambda_function.sidecar.function_name}"
  retention_in_days = 7
}

resource "aws_lambda_permission" "s3_sidecar" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sidecar.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.storage.landing_bucket_arn
}

resource "aws_s3_bucket_notification" "landing_trigger" {
  bucket = module.storage.landing_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.sidecar.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
  }

  depends_on = [aws_lambda_permission.s3_sidecar]
}

# =============================================================================
# M0-04 — OpenSearch Serverless Vector Store + Bedrock Knowledge Base
# =============================================================================

# ── OpenSearch Serverless security policies ──────────────────────────────────

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "${var.project_name}-enc"
  type        = "encryption"
  description = "KMS encryption for vector collection"
  policy = jsonencode({
    Rules = [{ Resource = ["collection/${var.project_name}-vectors"], ResourceType = "collection" }]
    AWSOwnedKey = true
  })
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "${var.project_name}-net"
  type        = "network"
  description = "VPC access for vector collection"
  policy = jsonencode([{
    Rules = [
      { Resource = ["collection/${var.project_name}-vectors"], ResourceType = "collection" },
      { Resource = ["dashboards/default"],                     ResourceType = "dashboard" }
    ]
    AllowFromPublic = false
    SourceVPCEs     = [data.terraform_remote_state.shared.outputs.endpoint_ids["execute-api"]]
  }])
}

resource "aws_opensearchserverless_access_policy" "bedrock_kb" {
  name        = "${var.project_name}-kb-access"
  type        = "data"
  description = "Allow Bedrock KB service role to read/write the vector index"
  policy = jsonencode([{
    Rules = [
      {
        Resource     = ["collection/${var.project_name}-vectors"]
        Permission   = ["aoss:CreateCollectionItems", "aoss:DeleteCollectionItems",
                        "aoss:UpdateCollectionItems", "aoss:DescribeCollectionItems"]
        ResourceType = "collection"
      },
      {
        Resource     = ["index/${var.project_name}-vectors/*"]
        Permission   = ["aoss:CreateIndex", "aoss:DeleteIndex", "aoss:UpdateIndex",
                        "aoss:DescribeIndex", "aoss:ReadDocument", "aoss:WriteDocument"]
        ResourceType = "index"
      }
    ]
    Principal = [aws_iam_role.bedrock_kb.arn]
  }])
}

resource "aws_opensearchserverless_collection" "vectors" {
  name = "${var.project_name}-vectors"
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption,
    aws_opensearchserverless_security_policy.network,
    aws_opensearchserverless_access_policy.bedrock_kb,
  ]

  tags = { Name = "${var.project_name}-vectors" }
}

# ── Create the knn vector index (runs once after collection is ACTIVE) ────────

resource "null_resource" "opensearch_index" {
  triggers = { collection_endpoint = aws_opensearchserverless_collection.vectors.collection_endpoint }

  provisioner "local-exec" {
    command = "python3 ${path.module}/scripts/create_opensearch_index.py"
    environment = {
      COLLECTION_ENDPOINT = aws_opensearchserverless_collection.vectors.collection_endpoint
      AWS_REGION          = var.region
      INDEX_NAME          = "bedrock-knowledge-base-default-index"
    }
  }
}

# ── IAM role for Bedrock KB ───────────────────────────────────────────────────

resource "aws_iam_role" "bedrock_kb" {
  name = "${var.project_name}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name = "bedrock-kb-permissions"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:ListBucket"]
        Resource = [module.storage.processed_bucket_arn, "${module.storage.processed_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["aoss:APIAccessAll"]
        Resource = aws_opensearchserverless_collection.vectors.arn
      }
    ]
  })
}

# ── Bedrock Knowledge Base ────────────────────────────────────────────────────

resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-knowledge-base"
  role_arn = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "OPENSEARCH_SERVERLESS"
    opensearch_serverless_configuration {
      collection_arn    = aws_opensearchserverless_collection.vectors.arn
      vector_index_name = "bedrock-knowledge-base-default-index"
      field_mapping {
        vector_field   = "bedrock-knowledge-base-default-vector"
        text_field     = "AMAZON_BEDROCK_TEXT_CHUNK"
        metadata_field = "AMAZON_BEDROCK_METADATA"
      }
    }
  }

  depends_on = [null_resource.opensearch_index]

  tags = { Name = "${var.project_name}-knowledge-base" }
}

resource "aws_bedrockagent_data_source" "processed" {
  name              = "${var.project_name}-docs-source"
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn         = module.storage.processed_bucket_arn
      inclusion_prefixes = ["uploads/"]
    }
  }

  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 512
        overlap_percentage = 20
      }
    }
  }
}

# =============================================================================
# M0-05 — SES Identity
# =============================================================================

resource "aws_ses_email_identity" "digest_sender" {
  email = var.digest_sender_email
}

# =============================================================================
# M0-05 — Lambda: Weekly Digest
# =============================================================================

data "archive_file" "digest" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/digest"
  output_path = "${path.module}/lambda/digest.zip"
}

resource "aws_lambda_function" "digest" {
  function_name    = "${var.project_name}-weekly-digest"
  role             = aws_iam_role.lambda_exec.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.digest.output_path
  source_code_hash = data.archive_file.digest.output_base64sha256

  environment {
    variables = {
      DOCUMENTS_TABLE  = aws_dynamodb_table.documents.name
      DIGEST_RECIPIENT = var.digest_recipient_email
      DIGEST_SENDER    = var.digest_sender_email
      BEDROCK_KB_ID    = ""  # filled after KB is applied
      BEDROCK_DS_ID    = ""  # filled after KB is applied
    }
  }
  # No VPC config — accesses DynamoDB via gateway endpoint; SES via internet or NAT
}

resource "aws_cloudwatch_log_group" "digest" {
  name              = "/aws/lambda/${aws_lambda_function.digest.function_name}"
  retention_in_days = 14
}

# =============================================================================
# M0-05 — EventBridge: Weekly Schedule (Monday 08:00 UTC)
# =============================================================================

resource "aws_cloudwatch_event_rule" "weekly_digest" {
  name                = "${var.project_name}-weekly-digest"
  description         = "Trigger weekly knowledge base digest email"
  schedule_expression = "cron(0 8 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "digest_lambda" {
  rule      = aws_cloudwatch_event_rule.weekly_digest.name
  target_id = "DigestLambda"
  arn       = aws_lambda_function.digest.arn
}

resource "aws_lambda_permission" "eventbridge_digest" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.digest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_digest.arn
}

# =============================================================================
# M0-05 — CloudWatch: SNS Alarm Topic + Alarms + Dashboard
# =============================================================================

resource "aws_sns_topic" "alarms" {
  name = "${var.project_name}-team1-alarms"
}

resource "aws_sns_topic_subscription" "alarm_email" {
  topic_arn = aws_sns_topic.alarms.arn
  protocol  = "email"
  endpoint  = var.digest_recipient_email
}

locals {
  monitored_lambdas = {
    presign = aws_lambda_function.presign.function_name
    sidecar = aws_lambda_function.sidecar.function_name
    digest  = aws_lambda_function.digest.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_errors" {
  for_each = local.monitored_lambdas

  alarm_name          = "${var.project_name}-${each.key}-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Lambda ${each.key} is throwing errors"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { FunctionName = each.value }
}

resource "aws_cloudwatch_metric_alarm" "lambda_throttles" {
  for_each = local.monitored_lambdas

  alarm_name          = "${var.project_name}-${each.key}-throttles"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Throttles"
  namespace           = "AWS/Lambda"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "Lambda ${each.key} is being throttled"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = { FunctionName = each.value }
}

resource "aws_cloudwatch_metric_alarm" "apigw_5xx" {
  alarm_name          = "${var.project_name}-apigw-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = 300
  statistic           = "Sum"
  threshold           = 5
  alarm_description   = "API Gateway 5XX errors"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }
}

resource "aws_cloudwatch_metric_alarm" "apigw_latency" {
  alarm_name          = "${var.project_name}-apigw-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 300
  extended_statistic  = "p99"
  threshold           = 3000
  alarm_description   = "API Gateway p99 latency > 3s"
  treat_missing_data  = "notBreaching"
  alarm_actions       = [aws_sns_topic.alarms.arn]

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-team1"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title   = "Lambda Invocations & Errors"
          period  = 300
          stat    = "Sum"
          metrics = [
            for fn_name in values(local.monitored_lambdas) : [
              ["AWS/Lambda", "Invocations", "FunctionName", fn_name],
              ["AWS/Lambda", "Errors", "FunctionName", fn_name]
            ]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "API Gateway Latency p99"
          period  = 300
          stat    = "p99"
          metrics = [["AWS/ApiGateway", "Latency", "ApiName",
            aws_api_gateway_rest_api.main.name, "Stage", var.environment]]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "API Gateway 4XX / 5XX"
          period  = 300
          stat    = "Sum"
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", var.environment],
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", var.environment]
          ]
        }
      }
    ]
  })
}
