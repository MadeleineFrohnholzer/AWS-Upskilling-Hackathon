# =============================================================================
# Shared Infrastructure (Pre-provisioned before hackathon)
# =============================================================================
# This deploys the VPC, networking, VPC endpoints, and ALB skeleton.
# Both teams consume these outputs via terraform_remote_state.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket         = "hackathon-tf-state-064453091991"
    key            = "shared/terraform.tfstate"
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
      Environment = "shared"
      ManagedBy   = "terraform"
    }
  }
}

# =============================================================================
# Current account identity (used in IAM trust policies)
# =============================================================================
data "aws_caller_identity" "current" {}

# =============================================================================
# IAM Participant Roles
# =============================================================================

resource "aws_iam_role" "team1_developer" {
  name = "hackathon-team1-developer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "hackathon-team1-developer" }
}

resource "aws_iam_role_policy" "team1_developer" {
  name = "team1-scoped-access"
  role = aws_iam_role.team1_developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/team1/*"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject"]
        Resource = [
          "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/shared/*",
          "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/team2/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:eu-central-1:${data.aws_caller_identity.current.account_id}:table/hackathon-tf-locks"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:*", "lambda:*", "apigateway:*", "dynamodb:*", "bedrock:*", "bedrock-agent:*",
                    "iam:PassRole", "iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy",
                    "logs:*", "events:*", "ses:*", "sns:*"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "elasticloadbalancing:Describe*"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role" "team0_operator" {
  name = "hackathon-team0-operator"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = { Name = "hackathon-team0-operator" }
}

resource "aws_iam_role_policy_attachment" "team0_admin" {
  role       = aws_iam_role.team0_operator.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

# =============================================================================
# Networking Module
# =============================================================================

module "networking" {
  source = "../modules/networking"

  project_name         = var.project_name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
  enable_nat_gateway   = var.enable_nat_gateway
}
