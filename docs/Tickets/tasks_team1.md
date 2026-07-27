# M1 — Access & Knowledge App: Detailed Ticket Specifications

> **Milestone owner:** Team 1 (Zoltan, Nikos, Yildrim, Nicolas)
> **Definition of done:** A user logs in via SSO, asks a question, and gets a cited answer from the KB.
> **State file:** `team1/terraform.tfstate` — backend bucket `hackathon-tf-state-064453091991`, region `eu-central-1`
> **Critical inputs from Team 0:** `bedrock_kb_id`, `bedrock_kb_arn` (read via `terraform_remote_state.team0`)

---

## What's Already Done (Compute Module — Day 1 Complete)

The `modules/compute` module already provisions:

| Resource | Name pattern | Status |
|----------|-------------|--------|
| ECR repository | `knowledge-base-chat-frontend` | Done — image scanning enabled |
| ECS cluster | `knowledge-base-cluster` | Done — Container Insights enabled |
| ECS task execution IAM role | `platform-knowledge-base-ecs-task-execution` | Done — AmazonECSTaskExecutionRolePolicy attached |
| CloudWatch log group | `/ecs/knowledge-base-chat-frontend` | Done — 14-day retention |

**Remaining work is organized into five tickets below.**

---

## TICKET M1-01 — Cognito User Pool + Microsoft Entra ID SSO Federation

### Goal

Provision a Cognito User Pool that delegates authentication entirely to Microsoft Entra ID (Azure AD) via OIDC. All six hackathon participants log in with their Accenture `@accenture.com` credentials — no separate password to manage. The ALB will use Cognito as the authentication gatekeeper before forwarding requests to Open WebUI.

### Prerequisites (Azure Portal — done by Zoltan or Nikos)

1. In Entra ID → App Registrations → **New registration**
   - Name: `knowledge-base-hackathon`
   - Redirect URI type: **Web**, value: `https://<cognito-domain>.auth.eu-central-1.amazoncognito.com/oauth2/idpresponse`
2. Note the **Tenant ID** and **Client ID** from the app's Overview page
3. Under Certificates & secrets → New client secret → note the **Client Secret value** (visible once only)
4. Under API permissions → add `openid`, `email`, `profile` (Microsoft Graph delegated)

### Terraform Resources

```hcl
# Cognito User Pool — SSO authentication front door
resource "aws_cognito_user_pool" "main" {
  name = "${var.project_name}-users"

  admin_create_user_config {
    allow_admin_create_user_only = true  # users come exclusively via Entra ID SSO
  }

  password_policy {
    minimum_length                   = 12
    require_lowercase                = true
    require_numbers                  = true
    require_symbols                  = true
    require_uppercase                = true
    temporary_password_validity_days = 1
  }

  auto_verified_attributes = ["email"]
  username_attributes      = ["email"]

  schema {
    attribute_data_type      = "String"
    name                     = "email"
    required                 = true
    mutable                  = true
    developer_only_attribute = false
    string_attribute_constraints { min_length = 3, max_length = 254 }
  }
}

# Cognito hosted-UI domain — used by ALB authenticator redirect
resource "aws_cognito_user_pool_domain" "main" {
  domain       = "${var.project_name}-${data.aws_caller_identity.current.account_id}"
  user_pool_id = aws_cognito_user_pool.main.id
}

# Microsoft Entra ID OIDC identity provider
resource "aws_cognito_identity_provider" "entra" {
  user_pool_id  = aws_cognito_user_pool.main.id
  provider_name = "EntraID"
  provider_type = "OIDC"

  provider_details = {
    client_id                 = var.entra_client_id
    client_secret             = var.entra_client_secret
    attributes_request_method = "GET"
    oidc_issuer               = "https://login.microsoftonline.com/${var.entra_tenant_id}/v2.0"
    authorize_scopes          = "openid email profile"
    authorize_url             = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/authorize"
    token_url                 = "https://login.microsoftonline.com/${var.entra_tenant_id}/oauth2/v2.0/token"
    attributes_url            = "https://graph.microsoft.com/oidc/userinfo"
    jwks_uri                  = "https://login.microsoftonline.com/${var.entra_tenant_id}/discovery/v2.0/keys"
  }

  attribute_mapping = {
    email    = "email"
    username = "sub"
    name     = "name"
  }
}

# Cognito App Client — used by the ALB listener rule authenticator
resource "aws_cognito_user_pool_client" "open_webui" {
  name         = "open-webui-alb"
  user_pool_id = aws_cognito_user_pool.main.id

  generate_secret                      = true
  allowed_oauth_flows                  = ["code"]
  allowed_oauth_flows_user_pool_client = true
  allowed_oauth_scopes                 = ["email", "openid", "profile"]

  callback_urls = ["https://${local.alb_dns_name}/oauth2/idpresponse"]
  logout_urls   = ["https://${local.alb_dns_name}"]

  supported_identity_providers = ["EntraID"]
  depends_on                   = [aws_cognito_identity_provider.entra]
}
```

Variables to set in `terraform.tfvars` (never commit these — use AWS Secrets Manager or environment variables in CI):

```hcl
# terraform/team1/terraform.tfvars  (git-ignored)
entra_tenant_id     = "<your-accenture-tenant-guid>"
entra_client_id     = "<app-registration-client-id>"
entra_client_secret = "<app-registration-client-secret>"
```

### Acceptance Criteria

- [ ] `terraform apply` creates the Cognito User Pool, domain, Entra ID OIDC provider, and app client
- [ ] Entra ID redirect URI is registered in the Azure App Registration (matches `https://<cognito-domain>/oauth2/idpresponse`)
- [ ] Visiting `https://<alb_dns_name>` redirects to the Accenture Microsoft login page
- [ ] All 6 team members can authenticate with their `@accenture.com` credentials
- [ ] After login, the browser holds a valid `AWSELBAuthSessionCookie`
- [ ] `aws cognito-idp list-users --user-pool-id <id>` shows federated user entries after first login

### Effort Estimate

**Day 2 morning** — Cognito + Entra wiring (~1.5h); Azure app registration (~30min)

### Key Pitfalls

- The Cognito hosted-UI domain must be globally unique — using `${project_name}-${account_id}` avoids collisions
- The Entra ID redirect URI must match **exactly** (including trailing slash, HTTPS, no typos) — a mismatch causes `redirect_uri_mismatch` OIDC errors
- The ALB uses HTTPS (self-signed cert) — browsers will show a cert warning on first access inside VPN; click through or import the CA. Do NOT switch to HTTP — Cognito auth requires HTTPS
- `generate_secret = true` is required for ALB integration; user-side OAuth flows use the secret, not the user
- After the OIDC provider is created, re-run `terraform apply` for the app client — it depends on the provider

---

## TICKET M1-02 — ECR Image Build + ECS Fargate Service (Open WebUI)

### Goal

Build and push the Open WebUI Docker image to ECR, then deploy it as an ECS Fargate service. Open WebUI is the chat frontend that users interact with after logging in. The container reads Bedrock Agent configuration from environment variables and the SSM secret key.

### Step 1: Build and push the image (run once, then update variable)

```bash
# Authenticate Docker to ECR
aws ecr get-login-password --region eu-central-1 | \
  docker login --username AWS --password-stdin \
  064453091991.dkr.ecr.eu-central-1.amazonaws.com

# Pull Open WebUI image
docker pull ghcr.io/open-webui/open-webui:main

# Tag and push to ECR
docker tag ghcr.io/open-webui/open-webui:main \
  064453091991.dkr.ecr.eu-central-1.amazonaws.com/knowledge-base-chat-frontend:latest

docker push \
  064453091991.dkr.ecr.eu-central-1.amazonaws.com/knowledge-base-chat-frontend:latest
```

Then set in `terraform.tfvars`:
```hcl
open_webui_image = "064453091991.dkr.ecr.eu-central-1.amazonaws.com/knowledge-base-chat-frontend:latest"
```

### Terraform Resources

```hcl
# SSM parameter for Open WebUI session-signing key
resource "aws_ssm_parameter" "webui_secret_key" {
  name  = "/${var.project_name}/open-webui/secret-key"
  type  = "SecureString"
  value = "REPLACE_ME_CHANGE_AFTER_FIRST_DEPLOY_MIN_32_CHARS"
  lifecycle { ignore_changes = [value] }
}

resource "aws_cloudwatch_log_group" "open_webui" {
  name              = "/ecs/${var.project_name}-open-webui"
  retention_in_days = 14
}

# ECS task role — runtime AWS API calls from the container
resource "aws_iam_role" "ecs_task" {
  name = "${var.project_name}-open-webui-task"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Effect = "Allow", Action = "sts:AssumeRole",
      Principal = { Service = "ecs-tasks.amazonaws.com" } }]
  })
}

resource "aws_iam_role_policy" "ecs_task" {
  name = "open-webui-bedrock-access"
  role = aws_iam_role.ecs_task.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "BedrockAgentInvoke"
        Effect = "Allow"
        Action = ["bedrock-agent-runtime:InvokeAgent",
                  "bedrock-agent-runtime:Retrieve",
                  "bedrock-agent-runtime:RetrieveAndGenerate"]
        Resource = [
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent/${aws_bedrockagent_agent.main.agent_id}",
          "arn:aws:bedrock:${local.region}:${local.account_id}:agent-alias/${aws_bedrockagent_agent.main.agent_id}/*",
          "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${local.bedrock_kb_id}",
        ]
      },
      { Sid = "SSMRead", Effect = "Allow",
        Action = ["ssm:GetParameter"],
        Resource = aws_ssm_parameter.webui_secret_key.arn }
    ]
  })
}

resource "aws_ecs_task_definition" "open_webui" {
  family                   = "${var.project_name}-open-webui"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "1024"
  memory                   = "2048"
  execution_role_arn       = module.compute.ecs_task_execution_role_arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([{
    name  = "open-webui"
    image = local.container_image   # ECR URL or var.open_webui_image
    portMappings = [{ containerPort = 8080, protocol = "tcp" }]
    environment = [
      { name = "WEBUI_AUTH",           value = "true"  },
      { name = "ENABLE_SIGNUP",        value = "false" },
      { name = "DEFAULT_USER_ROLE",    value = "user"  },
      { name = "AWS_REGION",           value = local.region },
      { name = "BEDROCK_AGENT_ID",     value = aws_bedrockagent_agent.main.agent_id },
      { name = "BEDROCK_AGENT_ALIAS_ID", value = aws_bedrockagent_agent_alias.live.agent_alias_id },
      { name = "KNOWLEDGE_BASE_ID",    value = local.bedrock_kb_id },
    ]
    secrets = [{ name = "WEBUI_SECRET_KEY",
                 valueFrom = aws_ssm_parameter.webui_secret_key.arn }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = aws_cloudwatch_log_group.open_webui.name
        "awslogs-region"        = local.region
        "awslogs-stream-prefix" = "open-webui"
      }
    }
    healthCheck = {
      command     = ["CMD-SHELL", "curl -sf http://localhost:8080/health || exit 1"]
      interval    = 30, timeout = 5, retries = 3, startPeriod = 60
    }
  }])
}

resource "aws_ecs_service" "open_webui" {
  name            = "${var.project_name}-open-webui"
  cluster         = module.compute.ecs_cluster_arn
  task_definition = aws_ecs_task_definition.open_webui.arn
  desired_count   = 1
  launch_type     = "FARGATE"
  force_new_deployment = true

  network_configuration {
    subnets         = local.private_subnet_ids
    security_groups = [local.ecs_tasks_security_group_id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.chat_frontend.arn
    container_name   = "open-webui"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener_rule.chat_frontend]
}
```

### Acceptance Criteria

- [x] `terraform apply` creates the ECS task definition, service, IAM task role, SSM parameter, and log group
- [ ] Image appears in ECR: `aws ecr list-images --repository-name knowledge-base-chat-frontend`
- [ ] ECS service shows 1/1 running tasks: `aws ecs describe-services --cluster knowledge-base-cluster --services knowledge-base-open-webui`
- [ ] Container health check passes — task reaches `RUNNING` state without cycling
- [ ] CloudWatch log group `/ecs/knowledge-base-open-webui` receives logs within 2 minutes of service start
- [ ] Change `WEBUI_SECRET_KEY` SSM value via console after first deploy (lifecycle `ignore_changes` protects it on subsequent applies)

### Effort Estimate

**Day 2 afternoon** — Docker push (~30min), Terraform (~45min), troubleshooting (~45min)

### Key Pitfalls

- ECR image pull happens inside the private VPC — the `ecr.api` and `ecr.dkr` VPC endpoints (provisioned by Team 0) are required; pulls will time out without them
- Container CPU/memory: Open WebUI needs at least 512 CPU / 1024 MiB; using 1024 / 2048 avoids OOM on startup
- `WEBUI_SECRET_KEY` must be at least 32 characters — if the placeholder value is too short, Open WebUI will refuse to start
- The `force_new_deployment = true` flag forces a fresh task launch on every `terraform apply`; useful during hackathon iteration but will briefly interrupt users
- If the health check fails, check that `/health` returns 200. Open WebUI may take 60+ seconds to initialize (startup DB migrations) — the `startPeriod = 60` handles this

---

## TICKET M1-03 — ALB Target Group + Cognito Listener Rule

### Goal

Wire the ECS Open WebUI service to the **shared internal ALB** (provisioned by Team 0 in `terraform/shared`) using an ALB listener rule that first authenticates via Cognito and then forwards authenticated requests to the ECS target group. This is the single HTTPS entry point for all users.

### Architecture

```
User (inside VPN)
  │  HTTPS 443
  ▼
Shared Internal ALB  (alb_listener_arn from shared state)
  │  listener rule priority 100
  ▼
authenticate-cognito action  ──► Cognito Hosted UI ──► Entra ID SSO
  │  on success: sets AWSELBAuthSessionCookie
  ▼
forward action
  │
  ▼
Target Group  (ip, port 8080)
  │
  ▼
ECS Fargate Task  (Open WebUI container)
```

### Terraform Resources

```hcl
resource "aws_lb_target_group" "chat_frontend" {
  name        = "${var.project_name}-chat-tg"
  port        = 8080
  protocol    = "HTTP"
  vpc_id      = local.vpc_id
  target_type = "ip"   # required for Fargate awsvpc networking

  health_check {
    enabled             = true
    path                = "/health"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }
}

resource "aws_lb_listener_rule" "chat_frontend" {
  listener_arn = local.alb_listener_arn   # HTTPS listener from shared state
  priority     = 100

  action {
    type = "authenticate-cognito"
    authenticate_cognito {
      user_pool_arn              = aws_cognito_user_pool.main.arn
      user_pool_client_id        = aws_cognito_user_pool_client.open_webui.id
      user_pool_domain           = aws_cognito_user_pool_domain.main.domain
      on_unauthenticated_request = "authenticate"
      session_cookie_name        = "AWSELBAuthSessionCookie"
      session_timeout            = 28800   # 8 hours
    }
  }

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.chat_frontend.arn
  }

  condition {
    path_pattern { values = ["/*"] }
  }
}
```

### Acceptance Criteria

- [x] `terraform apply` creates the target group and listener rule on the shared ALB
- [ ] `aws elbv2 describe-target-groups` shows `knowledge-base-chat-tg` as `active`
- [ ] Visiting `https://<alb_dns_name>` redirects to the Accenture Entra ID login page (unauthenticated)
- [ ] After login, the browser is redirected back to Open WebUI (not a 502/503)
- [ ] Target health check shows targets as `healthy`: `aws elbv2 describe-target-health --target-group-arn <arn>`
- [ ] Requests from outside the VPC (no VPN) receive a connection timeout — not a 200

### Effort Estimate

**Day 2 afternoon** — ~30min (depends on M1-01 and M1-02 being done first)

### Key Pitfalls

- The shared ALB has a **self-signed TLS certificate** — the ALB can still perform Cognito auth with self-signed certs, but browsers will show a certificate warning. This is expected during the hackathon
- `target_type = "ip"` is mandatory for Fargate tasks (awsvpc network mode); `instance` type won't work
- Listener rule priority 100 may conflict if other rules exist — check `aws elbv2 describe-rules --listener-arn <arn>` before applying
- The `authenticate-cognito` action must be the **first** action block; `forward` must be second — order matters in the HCL
- Health check path `/health` bypasses Cognito auth at the ALB level — it goes directly to the container

---

## TICKET M1-04 — Bedrock Agent + Knowledge Base Association

### Goal

Create a Bedrock Agent backed by Claude 3.5 Sonnet that retrieves documents from Team 0's Knowledge Base and generates grounded answers with inline source citations. The agent uses the `RETRIEVE_AND_GENERATE` flow — no custom Lambda action group needed for basic RAG.

### Terraform Resources

```hcl
resource "aws_iam_role" "bedrock_agent" {
  name = "${var.project_name}-bedrock-agent"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = { "aws:SourceAccount" = local.account_id }
        ArnLike = {
          "aws:SourceArn" = "arn:aws:bedrock:${local.region}:${local.account_id}:agent/*"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_agent" {
  name = "bedrock-agent-kb-access"
  role = aws_iam_role.bedrock_agent.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "InvokeModel"
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = [
          "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-3-5-sonnet-20241022-v2:0",
          "arn:aws:bedrock:${local.region}::foundation-model/anthropic.claude-3-sonnet-20240229-v1:0",
        ]
      },
      {
        Sid      = "KnowledgeBaseRetrieve"
        Effect   = "Allow"
        Action   = ["bedrock:Retrieve", "bedrock:RetrieveAndGenerate"]
        Resource = "arn:aws:bedrock:${local.region}:${local.account_id}:knowledge-base/${local.bedrock_kb_id}"
      }
    ]
  })
}

resource "aws_bedrockagent_agent" "main" {
  agent_name              = "${var.project_name}-agent"
  description             = "Knowledge retrieval agent — searches Team 0 KB and returns cited answers"
  agent_resource_role_arn = aws_iam_role.bedrock_agent.arn
  foundation_model        = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  idle_session_ttl_in_seconds = 600

  instruction = <<-EOT
    You are a helpful knowledge assistant for Accenture consultants.
    When a user asks a question, search the knowledge base for relevant documents.
    Always base your answers strictly on the retrieved content — do not make up information.
    For every factual claim, cite the source document with the format: [Source: <filename>, Page <N>].
    Place citations inline, immediately after the sentence they support.
    If no relevant documents are found, say so clearly rather than guessing.
    Keep answers concise but complete. Use bullet points for lists of findings.
  EOT

  prepare_agent = true
}

resource "aws_bedrockagent_agent_knowledge_base_association" "main" {
  agent_id             = aws_bedrockagent_agent.main.agent_id
  description          = "Team 0 Knowledge Base — document corpus for retrieval"
  knowledge_base_id    = local.bedrock_kb_id
  knowledge_base_state = "ENABLED"
}

resource "aws_bedrockagent_agent_alias" "live" {
  agent_id         = aws_bedrockagent_agent.main.agent_id
  agent_alias_name = "live"
  description      = "Stable alias used by Open WebUI — points to DRAFT during hackathon"
  depends_on       = [aws_bedrockagent_agent_knowledge_base_association.main]
}
```

### Acceptance Criteria

- [x] `terraform apply` creates the Bedrock Agent, KB association, alias, and IAM role
- [ ] `aws bedrock-agent get-agent --agent-id <id>` shows `agentStatus: PREPARED`
- [ ] Test invocation returns a non-empty response with at least one citation:
  ```bash
  aws bedrock-agent-runtime invoke-agent \
    --agent-id <id> \
    --agent-alias-id <alias-id> \
    --session-id test-session-1 \
    --input-text "What documents do we have about banking regulations?" \
    --region eu-central-1 \
    output.json
  cat output.json | jq '.citations'
  ```
- [ ] Citations reference actual document names from the landing/processed S3 bucket
- [ ] `terraform output bedrock_agent_id` returns a non-empty ID
- [ ] `terraform output bedrock_agent_alias_id` returns the `live` alias ID

### Effort Estimate

**Day 3 morning** — IAM + Terraform (~45min); agent testing (~30min)

### Key Pitfalls

- Bedrock model access must be granted in the AWS console (T0-06 prerequisite) — the agent will return `AccessDeniedException` if Claude 3.5 Sonnet isn't enabled for this account
- `prepare_agent = true` tells the Terraform provider to call the `PrepareAgent` API after creation — without it, the agent stays in `NOT_PREPARED` state and InvokeAgent calls fail
- The KB must have at least one successfully ingested document before the agent returns meaningful answers — coordinate with Team 0 on the handoff checklist
- Agent alias `live` points to `DRAFT` during the hackathon — this is intentional. For production you'd create a numbered version first
- The `idle_session_ttl_in_seconds = 600` (10 min) means the agent context window resets after 10 minutes of silence; adjust if demos need longer sessions

---

## TICKET M1-05 — Grounded Answers + Clickable Citations in Open WebUI

### Goal

Configure Open WebUI to invoke the Bedrock Agent and surface source citations as clickable links. Every answer the assistant gives must include the document source, so users can verify the information and open the original file.

### Architecture — Answer Flow

```
User types question in Open WebUI
  │
  ▼
Open WebUI backend  →  bedrock-agent-runtime:InvokeAgent
                            │  (BEDROCK_AGENT_ID, BEDROCK_AGENT_ALIAS_ID from env)
                            ▼
                    Bedrock Agent (Claude 3.5 Sonnet)
                            │  Retrieve tool call
                            ▼
                    Bedrock Knowledge Base (Team 0)
                            │  top-k matching chunks + metadata
                            ▼
                    Claude synthesizes answer + formats inline citations
                            │
  ◄──────────────────────────
Open WebUI renders markdown with [Source: doc.pdf, Page 3] links
```

### Open WebUI Configuration (post-deploy, via UI)

After the ECS service is running and the Bedrock Agent is deployed:

1. **Admin Panel → Settings → Connections**
   - Add a new OpenAI-compatible API endpoint
   - URL: use a custom backend wrapper (see below) OR use the Bedrock Agent SDK integration
   
2. **Alternative — Direct Bedrock Agent backend** (recommended for hackathon):
   - Open WebUI supports custom function calling; configure `BEDROCK_AGENT_ID` and `BEDROCK_AGENT_ALIAS_ID` env vars (already set in task definition)
   - In `Admin Panel → Settings → Models`, add a model named `bedrock-agent` pointing to the Bedrock Agent runtime endpoint

3. **Citation rendering**: Open WebUI renders markdown by default. The Bedrock Agent's instruction formats citations as `[Source: <file>, Page <N>]`. These appear inline in the chat response. To make them clickable, wrap them in S3 presigned URL links:
   - Have Team 0 generate a presigned GET URL for each cited document
   - The agent instruction can reference a document retrieval endpoint

### Environment Variables (already set in ECS task definition)

| Variable | Value | Purpose |
|----------|-------|---------|
| `WEBUI_AUTH` | `true` | Require login (Cognito handles it via ALB) |
| `ENABLE_SIGNUP` | `false` | Block direct registration — SSO only |
| `BEDROCK_AGENT_ID` | `<terraform output>` | Which Bedrock Agent to invoke |
| `BEDROCK_AGENT_ALIAS_ID` | `<terraform output>` | Which alias (always `live`) |
| `KNOWLEDGE_BASE_ID` | `<terraform output from team0>` | Direct KB access for fallback |
| `AWS_REGION` | `eu-central-1` | For SDK calls |
| `WEBUI_SECRET_KEY` | from SSM | Session token signing |

### Acceptance Criteria

- [ ] A logged-in user can type a question and receive a non-empty answer within 30 seconds
- [ ] Every answer includes at least one citation in `[Source: <filename>, Page <N>]` format
- [ ] Citations reference documents that actually exist in the Team 0 processed S3 bucket
- [ ] The answer content matches the cited source (no hallucination — answers are grounded)
- [ ] Asking a question with no matching documents returns "I couldn't find relevant documents" (not a hallucinated answer)
- [ ] Response latency for a typical question is under 20 seconds end-to-end (KB retrieval + Claude generation)

### Effort Estimate

**Day 3 afternoon** — Open WebUI config (~1h); citation testing (~30min); demo prep (~30min)

### Key Pitfalls

- Open WebUI's native Bedrock integration may need a compatibility layer — if the built-in integration doesn't support `InvokeAgent`, write a small FastAPI proxy that accepts OpenAI-format requests, calls `InvokeAgent`, and returns the response in OpenAI format. Deploy as a second container in the ECS task definition
- Citation links need presigned GET URLs from Team 0's S3 processed bucket — coordinate with Team 0 to expose a presigned-GET Lambda or use the existing presigned-PUT API Gateway with a GET variant
- The Bedrock Agent adds ~2–5 seconds latency per retrieval hop — this is normal; inform users via a "Thinking..." indicator in the UI
- If Claude returns `ThrottlingException`, implement exponential backoff in the proxy layer; the Bedrock on-demand throughput can be saturated by rapid testing

---

## Team 1 → Demo Readiness Checklist

Run this before the final presentation:

| Item | Command to verify | Status |
|------|------------------|--------|
| ECS service running | `aws ecs describe-services --cluster knowledge-base-cluster --services knowledge-base-open-webui` shows `runningCount: 1` | |
| Cognito SSO working | Open `https://<alb_dns_name>` in browser → redirected to Microsoft login | |
| Bedrock Agent prepared | `aws bedrock-agent get-agent --agent-id $(terraform output -raw bedrock_agent_id)` shows `PREPARED` | |
| Agent returns citations | `aws bedrock-agent-runtime invoke-agent ...` returns `citations` array | |
| ECR image pushed | `aws ecr list-images --repository-name knowledge-base-chat-frontend` shows `latest` tag | |
| Open WebUI shows answers | Log in, ask "What banking documents do we have?" → cited answer appears | |
