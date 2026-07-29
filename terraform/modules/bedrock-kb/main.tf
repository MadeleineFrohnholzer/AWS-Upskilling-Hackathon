# =============================================================================
# Bedrock Knowledge Base — S3 vector store + processed bucket data source
# =============================================================================

locals {
  kb_name             = "content-knowledge-base"
  embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
  embedding_dimensions = 1024
  distance_metric     = "cosine"
  data_type           = "float32"
}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "bedrock_kb" {
  name = "platform-bedrock-knowledge-base"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

data "aws_caller_identity" "current" {}

# ── S3 Vectors ────────────────────────────────────────────────────────────────

resource "aws_s3vectors_vector_bucket" "kb" {
  vector_bucket_name = "content-vector-store"
}

resource "aws_s3vectors_index" "kb" {
  vector_bucket_name = aws_s3vectors_vector_bucket.kb.vector_bucket_name
  index_name         = "content-vector-search-index"
  data_type          = local.data_type
  dimension          = local.embedding_dimensions
  distance_metric    = local.distance_metric
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name = "bedrock-kb-permissions"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = ["bedrock:InvokeModel"]
        Resource = [local.embedding_model_arn]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          var.processed_bucket_arn,
          "${var.processed_bucket_arn}/*",
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "s3vectors:PutVectors",
          "s3vectors:GetVectors",
          "s3vectors:DeleteVectors",
          "s3vectors:QueryVectors",
        ]
        Resource = [
          aws_s3vectors_vector_bucket.kb.vector_bucket_arn,
          "${aws_s3vectors_vector_bucket.kb.vector_bucket_arn}/index/${aws_s3vectors_index.kb.index_name}",
        ]
      }
    ]
  })
}

# ── Knowledge Base ────────────────────────────────────────────────────────────

resource "aws_bedrockagent_knowledge_base" "main" {
  name     = local.kb_name
  role_arn = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = local.embedding_model_arn
      embedding_model_configuration {
        bedrock_embedding_model_configuration {
          dimensions = local.embedding_dimensions
          embedding_data_type = upper(local.data_type)
        }
      }
    }
  }

  storage_configuration {
    type = "S3_VECTORS"
    s3_vectors_configuration {
      index_name        = aws_s3vectors_index.kb.index_name
      vector_bucket_arn = aws_s3vectors_vector_bucket.kb.vector_bucket_arn
    }
  }
}

# ── Data Source ───────────────────────────────────────────────────────────────

resource "aws_bedrockagent_data_source" "processed" {
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id
  name              = "content-knowledge-base-datasource"

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = var.processed_bucket_arn
    }
  }


  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 300
        overlap_percentage = 20
      }
    }
  }
}
