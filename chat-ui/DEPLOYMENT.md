# Deployment Guide — Knowledge Assistant Chat UI

This guide covers local development, pushing the Docker image to Amazon ECR, and deploying to ECS via Terraform.

---

## Contents

1. [Environment Variables](#environment-variables)
2. [Local Development](#local-development)
3. [Docker — build and run locally](#docker--build-and-run-locally)
4. [Push to Amazon ECR](#push-to-amazon-ecr)
5. [Deploy to ECS (Terraform)](#deploy-to-ecs-terraform)
6. [Terraform outputs](#terraform-outputs)
7. [Secrets and security notes](#secrets-and-security-notes)

---

## Environment Variables

### Local development — `.env.local`

Create `.env.local` inside `chat-ui/` (never commit this file):

```bash
# AWS region where your Bedrock agent and DynamoDB table live
AWS_REGION=eu-central-1

# Local dev credentials — not needed on ECS (task role provides them automatically)
AWS_ACCESS_KEY_ID=
AWS_SECRET_ACCESS_KEY=

# Bedrock Agent IDs — from: terraform -chdir=terraform/team2 output bedrock_agent_id
BEDROCK_AGENT_ID=
BEDROCK_AGENT_ALIAS_ID=

# DynamoDB table — from: terraform -chdir=terraform/team1 output chat_history_table_name
DYNAMODB_TABLE_NAME=

# Upload Lambda — from: terraform -chdir=terraform/team1 output presigned_url_lambda_name
UPLOAD_LAMBDA_NAME=

# Displayed in the TopBar and browser title
NEXT_PUBLIC_APP_NAME=Knowledge Assistant
```

> **Tip:** When any env var is absent the app returns mock responses, so the UI is fully usable locally without AWS credentials.

### Production (ECS) — injected automatically by Terraform

All production env vars are set by `terraform/team2/main.tf` in the ECS task definition — you do **not** set them manually.

| Env var | Source |
|---------|--------|
| `AWS_REGION` | Hardcoded `eu-central-1` in Terraform locals |
| `BEDROCK_AGENT_ID` | `var.bedrock_agent_id` |
| `BEDROCK_AGENT_ALIAS_ID` | `var.bedrock_agent_alias_id` |
| `BEDROCK_KB_ID` | `var.bedrock_kb_id` |
| `DYNAMODB_TABLE_NAME` | `terraform_remote_state.team1.outputs.chat_history_table_name` |
| `UPLOAD_LAMBDA_NAME` | `terraform_remote_state.team1.outputs.presigned_url_lambda_name` |
| `NEXT_PUBLIC_APP_NAME` | `"Knowledge Assistant"` (hardcoded in task definition) |

AWS credentials are **not** env vars on ECS — the container inherits them from the ECS task IAM role.

---

## Local Development

```bash
cd chat-ui
npm install
# create .env.local as described above
npm run dev          # http://localhost:3000
```

---

## Docker — build and run locally

```bash
cd chat-ui

# Build
docker build -t chat-ui:local .

# Run with your local env file
docker run --rm -p 3000:3000 --env-file .env.local chat-ui:local

# Or with Docker Compose (mounts ~/.aws automatically)
docker compose up --build
```

The Dockerfile produces a lean production image using Next.js standalone output:

```
Stage 1 — deps:     npm ci (production deps only)
Stage 2 — builder:  npm run build  →  .next/standalone
Stage 3 — runner:   copies standalone output, EXPOSE 3000, CMD node server.js
```

---

## Push to Amazon ECR

### Prerequisites

| Requirement | How to get it |
|-------------|---------------|
| Docker Desktop | https://docs.docker.com/desktop/ |
| AWS CLI v2 | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| AWS credentials | `aws configure` or IAM Identity Center SSO login |
| IAM permissions | `ecr:GetAuthorizationToken`, `ecr:InitiateLayerUpload`, `ecr:UploadLayerPart`, `ecr:CompleteLayerUpload`, `ecr:PutImage`, `ecr:BatchCheckLayerAvailability` |

> The ECR repository `knowledge-base-chat-frontend` is created by Terraform (`terraform/modules/compute`). Apply team2 at least once before pushing an image.

---

### Step 1 — Get the ECR repository URI

**bash / macOS / Linux**
```bash
ECR_REPO=$(aws ecr describe-repositories \
  --repository-names "knowledge-base-chat-frontend" \
  --region eu-central-1 \
  --query "repositories[0].repositoryUri" \
  --output text)

echo $ECR_REPO
# 064453091991.dkr.ecr.eu-central-1.amazonaws.com/knowledge-base-chat-frontend
```

**PowerShell (Windows)**
```powershell
$ECR_REPO = aws ecr describe-repositories `
  --repository-names "knowledge-base-chat-frontend" `
  --region eu-central-1 `
  --query "repositories[0].repositoryUri" `
  --output text

Write-Host $ECR_REPO
# 064453091991.dkr.ecr.eu-central-1.amazonaws.com/knowledge-base-chat-frontend
```

---

### Step 2 — Authenticate Docker with ECR

ECR tokens expire after 12 hours. Run this once per session before pushing.

**bash / macOS / Linux**
```bash
aws ecr get-login-password --region eu-central-1 \
  | docker login --username AWS --password-stdin \
    "$(echo $ECR_REPO | cut -d/ -f1)"

# Login Succeeded
```

**PowerShell (Windows)**
```powershell
$REGISTRY = ($ECR_REPO -split "/")[0]   # strip the repo name, keep the registry host

aws ecr get-login-password --region eu-central-1 `
  | docker login --username AWS --password-stdin $REGISTRY

# Login Succeeded
```

---

### Step 3 — Build the Docker image

Run this from the `chat-ui/` directory.

**bash**
```bash
cd chat-ui
docker build -t chat-ui:latest .
```

**PowerShell**
```powershell
Set-Location chat-ui
docker build -t chat-ui:latest .
```

The build takes ~3–5 minutes on first run (downloads Node Alpine base image and installs all npm deps). Subsequent builds use the Docker layer cache and are much faster.

---

### Step 4 — Tag and push

Two tags are pushed: `:latest` (always the newest build) and `:<git-sha>` (immutable, useful for rollbacks).

**bash**
```bash
GIT_SHA=$(git rev-parse --short HEAD)

docker tag chat-ui:latest $ECR_REPO:latest
docker tag chat-ui:latest $ECR_REPO:$GIT_SHA

docker push $ECR_REPO:latest
docker push $ECR_REPO:$GIT_SHA

echo "Pushed: $ECR_REPO:$GIT_SHA"
```

**PowerShell**
```powershell
$GIT_SHA = git rev-parse --short HEAD

docker tag chat-ui:latest "${ECR_REPO}:latest"
docker tag chat-ui:latest "${ECR_REPO}:${GIT_SHA}"

docker push "${ECR_REPO}:latest"
docker push "${ECR_REPO}:${GIT_SHA}"

Write-Host "Pushed: ${ECR_REPO}:${GIT_SHA}"
```

---

### Complete copy-paste script (PowerShell)

```powershell
# Run from the repo root
Set-Location chat-ui

$REGION   = "eu-central-1"
$ECR_REPO = aws ecr describe-repositories `
              --repository-names "knowledge-base-chat-frontend" `
              --region $REGION `
              --query "repositories[0].repositoryUri" `
              --output text
$REGISTRY = ($ECR_REPO -split "/")[0]
$GIT_SHA  = git rev-parse --short HEAD

# 1. Authenticate
aws ecr get-login-password --region $REGION `
  | docker login --username AWS --password-stdin $REGISTRY

# 2. Build
docker build -t chat-ui:latest .

# 3. Tag
docker tag chat-ui:latest "${ECR_REPO}:latest"
docker tag chat-ui:latest "${ECR_REPO}:${GIT_SHA}"

# 4. Push
docker push "${ECR_REPO}:latest"
docker push "${ECR_REPO}:${GIT_SHA}"

Write-Host ""
Write-Host "Done. Image pushed as:"
Write-Host "  ${ECR_REPO}:latest"
Write-Host "  ${ECR_REPO}:${GIT_SHA}"
```

---

### Step 5 — Trigger a new ECS deployment

After pushing, ECS does **not** automatically redeploy. You must trigger it:

**Option A — force re-pull of `:latest` (fastest)**
```bash
aws ecs update-service \
  --cluster knowledge-base-cluster \
  --service knowledge-base-open-webui \
  --force-new-deployment \
  --region eu-central-1
```

**PowerShell**
```powershell
aws ecs update-service `
  --cluster knowledge-base-cluster `
  --service knowledge-base-open-webui `
  --force-new-deployment `
  --region eu-central-1
```

**Option B — pin to a specific image tag via Terraform (recommended for production)**
```bash
cd terraform/team2
terraform apply -var="chat_ui_image=$ECR_REPO:<git-sha>"
```

**Wait for the new task to become healthy:**
```bash
aws ecs wait services-stable \
  --cluster knowledge-base-cluster \
  --services knowledge-base-open-webui \
  --region eu-central-1

# Then verify the health endpoint
curl -s https://<your-alb-dns>/api/health
# Expected: {"status":"ok"}
```

---

### CI/CD — automatic push on merge (no manual steps needed)

`.github/workflows/docker.yml` runs automatically whenever code in `chat-ui/**` is merged to `main`. It authenticates with ECR via GitHub OIDC (no stored AWS keys), builds the image, and pushes `:latest` + `:<git-sha>`.

You only need the manual steps above for:
- Testing a local build before opening a PR
- Emergency hotfixes bypassing CI
- First-time push to bootstrap the ECR repository

---

## Deploy to ECS (Terraform)

### First deploy

```bash
# 1. Apply team1 (creates DynamoDB table, Lambdas, S3 buckets)
cd terraform/team1
terraform init && terraform apply

# 2. Push the Docker image (steps above)

# 3. Apply team2 (creates ECS service, Cognito, ALB rules)
cd ../team2
terraform init
terraform apply \
  -var="bedrock_agent_id=<agent-id>" \
  -var="bedrock_agent_alias_id=<alias-id>" \
  -var="bedrock_kb_id=<kb-id>" \
  -var="chat_ui_image=$ECR_REPO:latest" \
  -var="cognito_callback_urls=[\"https://<your-alb-dns>/oauth2/idpresponse\"]" \
  -var="entra_tenant_id=$ENTRA_TENANT_ID" \
  -var="entra_client_id=$ENTRA_CLIENT_ID" \
  -var="entra_client_secret=$ENTRA_CLIENT_SECRET"
```

### Rollback to a previous image

```bash
# List available tags in ECR
aws ecr list-images \
  --repository-name knowledge-base-chat-frontend \
  --region eu-central-1 \
  --query "imageIds[?imageTag!='latest'].imageTag" \
  --output table

# Roll back to a specific SHA
cd terraform/team2
terraform apply -var="chat_ui_image=$ECR_REPO:<previous-sha>"
```

---

## Terraform outputs

```bash
cd terraform/team2
terraform output alb_dns_name        # internal ALB DNS — access point for users on VPN
terraform output ecr_repository_url  # ECR URI for the chat-ui image
```

```bash
cd terraform/team1
terraform output chat_history_table_name   # DynamoDB table name
terraform output presigned_url_lambda_name # Upload Lambda name
```

---

## Secrets and security notes

- **Never commit** `.env.local` or any file with AWS credentials — `.gitignore` already excludes them
- On ECS the task IAM role provides credentials — no `AWS_ACCESS_KEY_ID` is ever set in the container
- Verify before pushing: `docker inspect chat-ui:latest` — confirm no `AWS_ACCESS_KEY_ID` in `Env`
- The ALB is **internal** — only reachable from the corporate VPN (`10.0.0.0/8` CIDR)
- Cognito + Entra ID SSO is enforced at the ALB listener — the app container never handles authentication
- ECR images are scanned for vulnerabilities on push (`scan_on_push = true` in Terraform)
