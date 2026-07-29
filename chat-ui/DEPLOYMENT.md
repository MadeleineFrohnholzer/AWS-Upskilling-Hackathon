# Deployment Guide — Knowledge Assistant Chat UI

This guide covers local development, pushing the Docker image to Amazon ECR, and deploying to ECS via Terraform.

---

## Environment Variables

### Local development — `.env.local`

Copy `.env.local.example` (or create `.env.local` in `chat-ui/`) with the following variables:

```bash
# AWS region where your Bedrock agent and DynamoDB table live
AWS_REGION=eu-central-1

# Local dev credentials (never commit; on ECS, the task role provides credentials automatically)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# Bedrock Agent — from Terraform output: terraform -chdir=terraform/team2 output bedrock_agent_id
BEDROCK_AGENT_ID=
BEDROCK_AGENT_ALIAS_ID=

# DynamoDB table for chat history — from Terraform output: terraform -chdir=terraform/team1 output chat_history_table_name
DYNAMODB_TABLE_NAME=

# Lambda function name for presigned S3 upload URLs — from Terraform output: terraform -chdir=terraform/team1 output presigned_url_lambda_name
UPLOAD_LAMBDA_NAME=

# (Optional) displayed in the TopBar and browser title
NEXT_PUBLIC_APP_NAME=Knowledge Assistant
```

> **Tip:** When any env var is absent the app falls back to mock responses, so the UI is fully usable locally without AWS credentials.

### Production (ECS) — set via Terraform

All production env vars are injected by `terraform/team2/main.tf` into the ECS task definition. You do **not** set them manually in production. They are resolved automatically from Terraform remote state:

| Env var | Source |
|---------|--------|
| `AWS_REGION` | Hardcoded in Terraform locals (`eu-central-1`) |
| `BEDROCK_AGENT_ID` | `var.bedrock_agent_id` (team2 Terraform variable) |
| `BEDROCK_AGENT_ALIAS_ID` | `var.bedrock_agent_alias_id` |
| `BEDROCK_KB_ID` | `var.bedrock_kb_id` |
| `DYNAMODB_TABLE_NAME` | `data.terraform_remote_state.team1.outputs.chat_history_table_name` |
| `UPLOAD_LAMBDA_NAME` | `data.terraform_remote_state.team1.outputs.presigned_url_lambda_name` |
| `NEXT_PUBLIC_APP_NAME` | `"Knowledge Assistant"` (hardcoded in task definition) |

AWS credentials are **not** set as env vars on ECS — the container inherits them from the ECS task IAM role (`platform-knowledge-base-open-webui-task`).

---

## Local Development

```bash
cd chat-ui
npm install
cp .env.local.example .env.local   # fill in your values
npm run dev                         # http://localhost:3000
```

---

## Docker — build and run locally

```bash
cd chat-ui

# Build
docker build -t chat-ui:local .

# Run (pass your .env.local as env file)
docker run --rm -p 3000:3000 --env-file .env.local chat-ui:local
```

Or with Docker Compose (mounts AWS credentials from `~/.aws`):

```bash
docker compose up --build
```

The Compose file mounts `~/.aws` read-only so the container can call Bedrock and DynamoDB with your local credentials.

---

## Push to Amazon ECR

### Prerequisites

- AWS CLI configured (`aws configure` or IAM Identity Center)
- Permissions: `ecr:GetAuthorizationToken`, `ecr:BatchGetImage`, `ecr:PutImage`

### 1 — Get the ECR repository URL

```bash
ECR_REPO=$(aws ecr describe-repositories \
  --repository-names "knowledge-base-chat-frontend" \
  --query "repositories[0].repositoryUri" \
  --output text)

echo $ECR_REPO   # e.g. 064453091991.dkr.ecr.eu-central-1.amazonaws.com/knowledge-base-chat-frontend
```

### 2 — Authenticate Docker with ECR

```bash
aws ecr get-login-password --region eu-central-1 \
  | docker login --username AWS --password-stdin \
    064453091991.dkr.ecr.eu-central-1.amazonaws.com
```

### 3 — Build, tag, and push

```bash
cd chat-ui

# Build
docker build -t chat-ui:latest .

# Tag with ECR URI
docker tag chat-ui:latest $ECR_REPO:latest
docker tag chat-ui:latest $ECR_REPO:$(git rev-parse --short HEAD)

# Push both tags
docker push $ECR_REPO:latest
docker push $ECR_REPO:$(git rev-parse --short HEAD)
```

### CI/CD — automatic push on merge

`.github/workflows/docker.yml` runs automatically on every push to `main` that touches `chat-ui/**`. It:
1. Authenticates with ECR using OIDC (no stored AWS keys)
2. Builds the Docker image
3. Pushes `:latest` and `:<git-sha>` tags

---

## Deploy to ECS (Terraform)

### First deploy

```bash
# 1. Make sure team1 infra is applied (DynamoDB + Lambdas)
cd terraform/team1
terraform init
terraform apply

# 2. Push the Docker image to ECR (see above)

# 3. Apply team2 (ECS service, Cognito, ALB rules)
cd ../team2
terraform init
terraform apply \
  -var="bedrock_agent_id=<agent-id>" \
  -var="bedrock_agent_alias_id=<alias-id>" \
  -var="bedrock_kb_id=<kb-id>" \
  -var="chat_ui_image=$ECR_REPO:latest" \
  -var="cognito_callback_urls=[\"https://<your-alb-dns>/oauth2/idpresponse\"]"
```

### Subsequent deploys (image update only)

After pushing a new image to ECR, force a new ECS deployment:

```bash
# Option A — force ECS to pull :latest
aws ecs update-service \
  --cluster knowledge-base-cluster \
  --service knowledge-base-open-webui \
  --force-new-deployment

# Option B — update the task definition image tag via Terraform
cd terraform/team2
terraform apply -var="chat_ui_image=$ECR_REPO:<new-sha>"
```

### Verify the deployment

```bash
# Wait for the service to stabilise (takes ~2 minutes)
aws ecs wait services-stable \
  --cluster knowledge-base-cluster \
  --services knowledge-base-open-webui

# Check the health endpoint through the ALB
curl -s https://<your-alb-dns>/api/health
# Expected: {"status":"ok"}
```

---

## Terraform outputs

After `terraform apply` on team2, useful outputs:

```bash
cd terraform/team2
terraform output alb_dns_name       # internal ALB DNS — share with the VPN/firewall team
terraform output ecr_repository_url # ECR URI for the chat-ui image
```

---

## Secrets and security notes

- **Never commit** `.env.local`, `.env*.local`, or any file containing AWS credentials
- The `.gitignore` already excludes these files
- On ECS, secrets are sourced from the IAM task role — no credentials are baked into the image
- Run `docker inspect <image>` and confirm no `AWS_ACCESS_KEY_ID` env var is present before pushing
- The ALB is **internal** — only reachable from the corporate VPN (`10.0.0.0/8` CIDR in the security group)
- Cognito + Entra ID SSO is enforced at the ALB listener — the container never handles authentication
