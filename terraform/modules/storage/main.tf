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
# S3 CORS: allow browsers to PUT directly to the landing bucket via presigned URL
resource "aws_s3_bucket_cors_configuration" "landing" {
  bucket = aws_s3_bucket.landing.id

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["PUT"]
    allowed_origins = var.cors_allowed_origins
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }
}

# -----------------------------------------------------------------------------
# DynamoDB: Document Audit Trail Table
# -----------------------------------------------------------------------------
resource "aws_dynamodb_table" "document_audit_trail" {
  name         = "${var.project_name}-document-audit-trail"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "filename"

  attribute {
    name = "filename"
    type = "S"
  }

  tags = {
    Name        = "${var.project_name}-document-audit-trail"
    Environment = var.environment
  }
}

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
