# =============================================================================
# Storage Module — S3 Buckets, DynamoDB Tables
# =============================================================================

# -----------------------------------------------------------------------------
# S3: Document Landing Bucket (raw uploads)
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "landing" {
  bucket_prefix = "${var.project_name}-landing-"

  tags = {
    Name        = "${var.project_name}-landing"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "landing" {
  bucket = aws_s3_bucket.landing.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "landing" {
  bucket                  = aws_s3_bucket.landing.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# S3: Processed Documents Bucket
# -----------------------------------------------------------------------------
resource "aws_s3_bucket" "processed" {
  bucket_prefix = "${var.project_name}-processed-"

  tags = {
    Name        = "${var.project_name}-processed"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_versioning" "processed" {
  bucket = aws_s3_bucket.processed.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "processed" {
  bucket = aws_s3_bucket.processed.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "processed" {
  bucket                  = aws_s3_bucket.processed.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# -----------------------------------------------------------------------------
# DynamoDB: Sessions Table
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "sessions" {
  name         = "${var.project_name}-sessions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "session_id"

  attribute {
    name = "session_id"
    type = "S"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-sessions"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# DynamoDB: Feedback Logs Table
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "feedback" {
  name         = "${var.project_name}-feedback"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "feedback_id"
  range_key    = "timestamp"

  attribute {
    name = "feedback_id"
    type = "S"
  }

  attribute {
    name = "timestamp"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-feedback"
    Environment = var.environment
  }
}

# -----------------------------------------------------------------------------
# DynamoDB: document-metadata Table
#
# Primary key: filename (S3 key) — one item per document
# GSIs enable the AI system to query by Industry, DocumentType, UseCase, Client:
#   IndustryIndex     — hash: Industry,      range: DocumentType  (e.g. all Case Studies for FSI)
#   DocumentTypeIndex — hash: DocumentType                        (e.g. all RFPs)
#   UseCaseIndex      — hash: UseCase                             (e.g. all Cloud Migration docs)
#   ClientIndex       — hash: Client                              (e.g. all Acme Corp docs)
# UploadedBy / UploadedAt are stored as item attributes only (no index needed yet).
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "document_metadata" {
  name         = "${var.project_name}-document-metadata"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "filename"

  attribute {
    name = "filename"
    type = "S"
  }

  attribute {
    name = "Industry"
    type = "S"
  }

  attribute {
    name = "DocumentType"
    type = "S"
  }

  attribute {
    name = "UseCase"
    type = "S"
  }

  attribute {
    name = "Client"
    type = "S"
  }

  global_secondary_index {
    name            = "IndustryIndex"
    hash_key        = "Industry"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "DocumentTypeIndex"
    hash_key        = "DocumentType"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "UseCaseIndex"
    hash_key        = "UseCase"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "ClientIndex"
    hash_key        = "Client"
    projection_type = "ALL"
  }

  tags = {
    Name        = "${var.project_name}-document-metadata"
    Environment = var.environment
  }
}
