# =============================================================================
# Bedrock Agent — grounded retrieval with inline citations
# =============================================================================

locals {
  agent_name = "bedrock-retrieval-agent"
  region     = data.aws_region.current.region
  account_id = data.aws_caller_identity.current.account_id
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# ── IAM ──────────────────────────────────────────────────────────────────────

resource "aws_iam_role" "agent" {
  name = "platform-bedrock-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike      = { "aws:SourceArn" = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/*" }
      }
    }]
  })
}

resource "aws_iam_role_policy" "agent" {
  name = "bedrock-model-and-kb"
  role = aws_iam_role.agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeFoundationModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel", "bedrock:InvokeModelWithResponseStream"]
        Resource = "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0"
      },
      {
        Sid    = "RetrieveFromKnowledgeBase"
        Effect = "Allow"
        Action = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
        # Scoped to the specific KB once it exists; wildcard acceptable for dev
        Resource = var.knowledge_base_arn != "" ? var.knowledge_base_arn : "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/*"
      }
    ]
  })
}

# ── Bedrock Agent ─────────────────────────────────────────────────────────────

resource "aws_bedrockagent_agent" "main" {
  agent_name                  = local.agent_name
  agent_resource_role_arn     = aws_iam_role.agent.arn
  foundation_model            = "anthropic.claude-3-sonnet-20240229-v1:0"
  instruction                 = var.agent_instruction
  idle_session_ttl_in_seconds = 600
  prepare_agent               = true
}

# Associate with the Knowledge Base once Team 1 has created it
resource "aws_bedrockagent_agent_knowledge_base_association" "main" {
  agent_id             = aws_bedrockagent_agent.main.id
  description          = "Primary document knowledge base for retrieval-augmented responses"
  knowledge_base_id    = var.knowledge_base_id
  knowledge_base_state = "ENABLED"
}

resource "aws_bedrockagent_agent_alias" "live" {
  agent_id         = aws_bedrockagent_agent.main.id
  agent_alias_name = "live"

  depends_on = [aws_bedrockagent_agent.main]
}
