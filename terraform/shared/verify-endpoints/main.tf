# =============================================================================
# Endpoint Verification — Test Lambda
# =============================================================================
# Deploys a Lambda function inside the VPC private subnet to verify
# all PrivateLink endpoints are reachable. Run once after provisioning:
#
#   aws lambda invoke --function-name knowledge-base-verify-endpoints \
#     --profile hackathon /dev/stdout
#
# Destroy after verification to avoid ongoing costs:
#   terraform destroy

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "hackathon-tf-state-REPLACE_WITH_ACCOUNT_ID"
    key            = "verify-endpoints/terraform.tfstate"
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
      Environment = "verification"
      ManagedBy   = "terraform"
      Temporary   = "true"
    }
  }
}

# Read shared networking outputs
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-REPLACE_WITH_ACCOUNT_ID"
    key    = "shared/terraform.tfstate"
    region = "eu-central-1"
  }
}

locals {
  vpc_id             = data.terraform_remote_state.shared.outputs.vpc_id
  private_subnet_ids = data.terraform_remote_state.shared.outputs.private_subnet_ids
  lambda_sg_id       = data.terraform_remote_state.shared.outputs.lambda_security_group_id
}

# -----------------------------------------------------------------------------
# IAM Role for verification Lambda
# -----------------------------------------------------------------------------
resource "aws_iam_role" "verify_lambda" {
  name = "${var.project_name}-verify-endpoints"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "verify_lambda" {
  name = "verify-endpoints-policy"
  role = aws_iam_role.verify_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "sts:GetCallerIdentity",
          "s3:ListAllMyBuckets",
          "dynamodb:ListTables",
          "bedrock:ListFoundationModels",
          "textract:DetectDocumentText",
          "ecr:DescribeRepositories",
          "logs:DescribeLogGroups",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      },
      {
        # Required for VPC-attached Lambda
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      }
    ]
  })
}

# -----------------------------------------------------------------------------
# Lambda Function (VPC-attached — uses PrivateLink endpoints)
# -----------------------------------------------------------------------------
data "archive_file" "verify_lambda" {
  type        = "zip"
  source_file = "${path.module}/lambda/index.py"
  output_path = "${path.module}/lambda/index.zip"
}

resource "aws_lambda_function" "verify_endpoints" {
  function_name    = "${var.project_name}-verify-endpoints"
  role             = aws_iam_role.verify_lambda.arn
  handler          = "index.lambda_handler"
  runtime          = "python3.12"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.verify_lambda.output_path
  source_code_hash = data.archive_file.verify_lambda.output_base64sha256

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_sg_id]
  }

  tags = {
    Name    = "${var.project_name}-verify-endpoints"
    Purpose = "Pre-hackathon endpoint verification"
  }
}

# -----------------------------------------------------------------------------
# CloudWatch Log Group
# -----------------------------------------------------------------------------
resource "aws_cloudwatch_log_group" "verify_lambda" {
  name              = "/aws/lambda/${var.project_name}-verify-endpoints"
  retention_in_days = 3
}
