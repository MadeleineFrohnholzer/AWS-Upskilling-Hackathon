# =============================================================================
# Bedrock Proxy — ECR repository for the OpenAI-compatible FastAPI proxy image
# =============================================================================
# Build and push with:
#   aws ecr get-login-password --region eu-central-1 | \
#     docker login --username AWS --password-stdin <ecr_repository_url>
#   docker build -t <ecr_repository_url>:latest .
#   docker push <ecr_repository_url>:latest

resource "aws_ecr_repository" "proxy" {
  name                 = "bedrock-proxy-image-repo"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "bedrock-proxy-image-repo"
    Environment = var.environment
  }
}
