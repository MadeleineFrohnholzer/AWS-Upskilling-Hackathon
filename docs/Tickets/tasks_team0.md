# Team 0 — Shared Infrastructure: Detailed Ticket Specifications

> **Owner:** Organizers / Platform team (must be complete **before Day 1 09:00**)
> **Purpose:** Pre-provision everything both teams consume via `terraform_remote_state`. Neither team can start coding until all tickets here are green.
> **State file:** `shared/terraform.tfstate` — backend bucket `hackathon-tf-state-064453091991`, region `eu-central-1`
> **Apply order:** T0-01 → T0-02 → T0-03 → T0-04 → T0-05 → T0-06 → T0-07

---

## TICKET T0-01 — AWS Account + IAM Participant Access

### Goal

Grant all hackathon participants access to the AWS account with least-privilege IAM roles scoped to their team's resources. No participant should have root or `AdministratorAccess`.

### Participant List

| Name | Email | Team | Role |
|------|-------|------|------|
| Aigul | aigul@accenture.com | Team 0 | team0-developer |
| Zoltan | zoltan.szilagyi@accenture.com | Team 1 | team1-developer |
| Sandro | sandro@accenture.com | Team 0 | team0-developer |
| Nikos | nikos@accenture.com | Team 1 | team1-developer |
| Yildrim | yildrim@accenture.com | Team 1 | team1-developer |
| Nicolas | nicolas@accenture.com | Team 1 | team1-developer |

### Terraform Resources

```hcl
# -------------------------------------------------------
# Team 0 IAM Role — Foundation / Ingestion (M0)
# -------------------------------------------------------
resource "aws_iam_role" "team0_developer" {
  name = "hackathon-team0-developer"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "team0_developer" {
  name = "team0-scoped-access"
  role = aws_iam_role.team0_developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Terraform state backend (read all, write only own key)
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/team0/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [
          "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/shared/*",
          "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/team1/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}"
      },
      # DynamoDB lock table
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:eu-central-1:${data.aws_caller_identity.current.account_id}:table/hackathon-tf-locks"
      },
      # Full access to resources tagged Team=team1-ingestion
      {
        Effect    = "Allow"
        Action    = ["s3:*", "lambda:*", "apigateway:*", "dynamodb:*", "bedrock:*",
                     "iam:PassRole", "logs:*", "events:*", "ses:*"]
        Resource  = "*"
        Condition = {
          StringEquals = { "aws:ResourceTag/Team" = "team0-ingestion" }
        }
      },
      # Allow creating tagged resources (tags checked at creation time)
      {
        Effect   = "Allow"
        Action   = ["s3:CreateBucket", "lambda:CreateFunction", "dynamodb:CreateTable",
                    "iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy"]
        Resource = "*"
      },
      # Read-only shared networking (cannot modify)
      {
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "elasticloadbalancing:Describe*"]
        Resource = "*"
      },
      # CloudWatch for own log groups
      {
        Effect   = "Allow"
        Action   = ["logs:*"]
        Resource = "arn:aws:logs:eu-central-1:${data.aws_caller_identity.current.account_id}:log-group:/aws/lambda/knowledge-base-*"
      }
    ]
  })
}

# -------------------------------------------------------
# Team 1 IAM Role — Access / Knowledge App (M1)
# -------------------------------------------------------
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
}

resource "aws_iam_role_policy" "team1_developer" {
  name = "team1-scoped-access"
  role = aws_iam_role.team1_developer.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Terraform state backend
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
        Resource = "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/team1/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"]
        Resource = [
          "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/shared/*",
          "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}/team0/*"
        ]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ListBucket"]
        Resource = "arn:aws:s3:::hackathon-tf-state-${data.aws_caller_identity.current.account_id}"
      },
      # DynamoDB lock table
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:DeleteItem"]
        Resource = "arn:aws:dynamodb:eu-central-1:${data.aws_caller_identity.current.account_id}:table/hackathon-tf-locks"
      },
      # Cognito, ECS, ECR, Bedrock Agent, ALB target groups
      {
        Effect   = "Allow"
        Action   = ["cognito-idp:*", "ecs:*", "ecr:*", "bedrock:*", "bedrock-agent:*",
                    "bedrock-agent-runtime:*", "elasticloadbalancing:*", "iam:PassRole",
                    "iam:CreateRole", "iam:PutRolePolicy", "iam:AttachRolePolicy",
                    "lambda:*", "apigateway:*", "ssm:*", "secretsmanager:*", "logs:*"]
        Resource = "*"
        Condition = {
          StringEquals = { "aws:ResourceTag/Team" = "team1-app" }
        }
      },
      # Allow creating tagged resources
      {
        Effect   = "Allow"
        Action   = ["iam:CreateRole", "iam:PutRolePolicy", "cognito-idp:CreateUserPool",
                    "ecs:CreateCluster", "ecr:CreateRepository"]
        Resource = "*"
      },
      # Read-only shared networking
      {
        Effect   = "Allow"
        Action   = ["ec2:Describe*", "elasticloadbalancing:Describe*"]
        Resource = "*"
      }
    ]
  })
}

data "aws_caller_identity" "current" {}
```

### AWS SSO / IAM Identity Center Setup (Manual)

If the account uses AWS IAM Identity Center (SSO):

1. Go to IAM Identity Center → Users → Add each participant
2. Create permission sets `team0-developer` and `team1-developer` with the policies above
3. Assign participants to permission sets in the `eu-central-1` account
4. Share the SSO start URL: `https://<org-id>.awsapps.com/start`

If using plain IAM users (simpler for hackathon):

```bash
# Create users and generate temporary credentials
for user in aigul zoltan sandro; do
  aws iam create-user --user-name "hackathon-$user"
  aws iam create-access-key --user-name "hackathon-$user"
  # Share access key + secret securely (use 1Password / SSM Parameter)
done
```

### AWS CLI Profile Setup (share with participants)

Participants add this to `~/.aws/config`:

```ini
[profile hackathon]
region = eu-central-1
role_arn = arn:aws:iam::064453091991:role/hackathon-team0-developer  # or team1
source_profile = default  # or sso, depending on auth method
```

Verify it works:

```bash
aws sts get-caller-identity --profile hackathon
```

### Acceptance Criteria

- [ ] All 6 participants can run `aws sts get-caller-identity --profile hackathon` successfully
- [ ] Team 0 members cannot modify Team 1 resources (and vice versa) — test by attempting `aws ecs list-clusters --profile hackathon` from a Team 0 account
- [ ] No participant has `AdministratorAccess` or root credentials
- [ ] Each team can read the other's Terraform state (needed for `terraform_remote_state` data sources)
- [ ] Terraform can assume the role and run `terraform plan` from each team's directory

### Effort Estimate

**Day -1 (evening before hackathon)** — 1 hour

---

## TICKET T0-02 — Terraform State Backend

### Goal

Bootstrap the S3 bucket and DynamoDB table used as the Terraform remote state backend. This must be the very first thing applied — all other Terraform configurations depend on it.

### What's Already Written

[terraform/backend/main.tf](../../terraform/backend/main.tf) already defines:
- `aws_s3_bucket.terraform_state` — KMS encrypted, versioned, `prevent_destroy = true`
- `aws_dynamodb_table.terraform_locks` — `LockID` hash key, PAY_PER_REQUEST
- Bucket name: `hackathon-tf-state-<account_id>` (e.g. `hackathon-tf-state-064453091991`)

### Apply Steps

The backend directory has **no remote backend itself** (bootstrapping problem) — it uses local state:

```bash
cd terraform/backend

terraform init        # local state only — no backend block in backend/main.tf
terraform apply

# Verify
aws s3 ls | grep hackathon-tf-state
aws dynamodb describe-table --table-name hackathon-tf-locks --query "Table.TableStatus"
```

After apply, note the bucket name and hard-code it in all team `backend {}` blocks (already done in team0/main.tf and team1/main.tf: `hackathon-tf-state-064453091991`).

### Missing Variable File

The backend module needs a `variables.tf`. Create it:

```hcl
# terraform/backend/variables.tf
variable "region" {
  description = "AWS region for state backend"
  type        = string
  default     = "eu-central-1"
}
```

### Post-Apply: State File Layout

| State Key | Who Applies | Contents |
|-----------|-------------|---------|
| `backend/terraform.tfstate` | Organizer (local) | State bucket + lock table |
| `shared/terraform.tfstate` | Organizer | VPC, networking, endpoints, ALB, security groups |
| `team0/terraform.tfstate` | Team 0 | S3, Lambda, API GW, Bedrock KB, DynamoDB |
| `team1/terraform.tfstate` | Team 1 | Cognito, ECS, ECR, Bedrock Agent, ALB rules |
| `verify-endpoints/terraform.tfstate` | Organizer | Temporary verification Lambda (destroy after Day 1) |

### Acceptance Criteria

- [ ] `aws s3 ls s3://hackathon-tf-state-064453091991` lists the bucket (no AccessDenied)
- [ ] `aws s3api get-bucket-versioning --bucket hackathon-tf-state-064453091991` returns `"Status": "Enabled"`
- [ ] `aws dynamodb describe-table --table-name hackathon-tf-locks` returns `"TableStatus": "ACTIVE"`
- [ ] `aws s3api get-bucket-encryption --bucket hackathon-tf-state-064453091991` shows SSE-KMS
- [ ] Running `terraform init` in `terraform/team0/` succeeds (backend can be reached)

### Effort Estimate

**Day -1** — 15 minutes (one-time bootstrap)

---

## TICKET T0-03 — VPC + Subnets + Route Tables + Security Groups

### Goal

Deploy the foundational network: one VPC (`10.0.0.0/16`), two public and two private subnets across `eu-central-1a` and `eu-central-1b`, route tables, and the baseline security groups used by Lambda, ECS, and the ALB.

### What's Already Written

[terraform/modules/networking/main.tf](../../terraform/modules/networking/main.tf) already covers:

| Resource | Details |
|----------|---------|
| `aws_vpc.main` | `10.0.0.0/16`, DNS support + hostnames enabled |
| `aws_subnet.public[0,1]` | `10.0.1.0/24`, `10.0.2.0/24` — no public IPs |
| `aws_subnet.private[0,1]` | `10.0.10.0/24`, `10.0.11.0/24` |
| `aws_internet_gateway.main` | Attached to VPC |
| `aws_route_table.public` | 0.0.0.0/0 → IGW |
| `aws_route_table.private` | No internet route (PrivateLink only) |
| `aws_nat_gateway.main` | Optional, `enable_nat_gateway = false` by default |
| `aws_security_group.lambda` | Egress 443 to VPC CIDR only |
| `aws_security_group.ecs_tasks` | Inbound 8080 from ALB SG, egress 443 to VPC CIDR |
| `aws_security_group.alb` | Inbound 443/80 from `10.0.0.0/8` (VPN), egress to VPC only |
| `aws_security_group.vpc_endpoints` | Inbound 443 from VPC CIDR |

### Apply Steps

```bash
cd terraform/shared
terraform init
terraform plan   # review — expect ~30 resources
terraform apply
```

### VPN CIDR Note

The ALB security group ingress uses `10.0.0.0/8` as the corporate VPN CIDR. Confirm the actual VPN IP range with the network team and adjust if needed:

```hcl
# In modules/networking/main.tf, ALB SG ingress:
cidr_blocks = [var.vpc_cidr, "10.0.0.0/8"]  # adjust "10.0.0.0/8" to actual VPN CIDR
```

### What to Verify After Apply

```bash
# VPC exists and DNS is enabled
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=knowledge-base-vpc" \
  --query "Vpcs[0].{ID:VpcId,DNS:EnableDnsSupport,CIDRBlock:CidrBlock}"

# 4 subnets (2 public, 2 private)
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<vpc-id>" \
  --query "Subnets[*].{Name:Tags[?Key=='Name']|[0].Value,CIDR:CidrBlock,AZ:AvailabilityZone}"

# 4 security groups created
aws ec2 describe-security-groups --filters "Name=vpc-id,Values=<vpc-id>" \
  --query "SecurityGroups[*].{Name:GroupName,ID:GroupId}"
```

### Acceptance Criteria

- [ ] VPC `10.0.0.0/16` exists with `EnableDnsSupport: true` and `EnableDnsHostnames: true`
- [ ] 4 subnets across 2 AZs — `eu-central-1a` and `eu-central-1b`
- [ ] Private subnets have **no route to 0.0.0.0/0** (confirm in route table)
- [ ] Public subnets route to the Internet Gateway
- [ ] 4 security groups exist: `*-vpce-sg`, `*-alb-*`, `*-lambda-*`, `*-ecs-*`
- [ ] Lambda SG has no inbound rules (Lambda initiates all connections outbound)
- [ ] ECS SG allows inbound 8080 only from ALB SG (not from 0.0.0.0/0)
- [ ] `terraform output vpc_id` returns a valid VPC ID

### Effort Estimate

**Day -1** — 30 minutes (includes verification)

---

## TICKET T0-04 — VPC Interface Endpoints (PrivateLink)

### Goal

Create all 7 PrivateLink interface endpoints and 2 Gateway endpoints so that Lambda, ECS, and Bedrock can reach AWS services without internet routing. This is the most critical security control: without these endpoints, nothing works inside the private subnets.

### Endpoint Inventory

| Endpoint | Type | Cost | Required by |
|----------|------|------|-------------|
| `s3` | Gateway | Free | All — S3 reads/writes |
| `dynamodb` | Gateway | Free | Team 0 Lambda → DynamoDB |
| `bedrock-runtime` | Interface | ~€7.50/mo/AZ | Team 0 sidecar Lambda → KB ingestion |
| `bedrock-agent-runtime` | Interface | ~€7.50/mo/AZ | Team 1 shim Lambda → Agent invocation |
| `textract` | Interface | ~€7.50/mo/AZ | Optional — OCR for scanned docs |
| `ecr.api` | Interface | ~€7.50/mo/AZ | ECS Fargate → ECR image pull (auth) |
| `ecr.dkr` | Interface | ~€7.50/mo/AZ | ECS Fargate → ECR image pull (layers) |
| `logs` | Interface | ~€7.50/mo/AZ | Lambda + ECS → CloudWatch Logs |
| `sts` | Interface | ~€7.50/mo/AZ | Lambda/ECS → IAM role assumption |

> **Cost note:** Interface endpoints with 2 AZs: 9 endpoints × 2 AZs × ~€0.013/h ≈ **€4.50/day**. Budget accordingly for the 4-day hackathon (~€18 in endpoint costs).

### Missing Endpoint for API Gateway

The networking module does not yet include the `execute-api` endpoint needed by Team 0 for the private API Gateway. Add it:

```hcl
# Add to terraform/modules/networking/main.tf

resource "aws_vpc_endpoint" "execute_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.execute-api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = {
    Name = "${var.project_name}-execute-api-endpoint"
  }
}
```

Add to `modules/networking/outputs.tf`:

```hcl
# Update the endpoint_ids output map to include execute-api:
output "endpoint_ids" {
  description = "Map of VPC endpoint service names to their IDs"
  value = {
    s3                    = aws_vpc_endpoint.s3.id
    dynamodb              = aws_vpc_endpoint.dynamodb.id
    bedrock_runtime       = aws_vpc_endpoint.bedrock_runtime.id
    bedrock_agent_runtime = aws_vpc_endpoint.bedrock_agent_runtime.id
    textract              = aws_vpc_endpoint.textract.id
    ecr_api               = aws_vpc_endpoint.ecr_api.id
    ecr_dkr               = aws_vpc_endpoint.ecr_dkr.id
    logs                  = aws_vpc_endpoint.logs.id
    sts                   = aws_vpc_endpoint.sts.id
    "execute-api"         = aws_vpc_endpoint.execute_api.id   # new
  }
}
```

### SSM Endpoint (Optional — needed if secrets are stored in Parameter Store)

```hcl
resource "aws_vpc_endpoint" "ssm" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.${var.region}.ssm"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = aws_subnet.private[*].id
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true

  tags = { Name = "${var.project_name}-ssm-endpoint" }
}
```

Add `ssm = aws_vpc_endpoint.ssm.id` to the `endpoint_ids` output. Team 1 needs this for Open WebUI's `WEBUI_SECRET_KEY` SSM Parameter.

### Verify DNS Resolution (from inside VPC)

After apply, each endpoint's hostname must resolve to a **private IP** (10.x.x.x):

```bash
# Run this inside the verify-endpoints Lambda (T0-07) or on an EC2 in the VPC
for svc in bedrock-runtime bedrock-agent-runtime textract api.ecr dkr.ecr logs sts execute-api ssm; do
  host "${svc}.eu-central-1.amazonaws.com" | head -1
done
# Expected: all resolve to 10.0.x.x addresses (VPC private IPs)
```

### Acceptance Criteria

- [ ] `aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=<vpc-id>"` lists 11 endpoints (9 original + execute-api + ssm)
- [ ] All Interface endpoints show `State: available`
- [ ] Gateway endpoints (s3, dynamodb) appear in the private route table
- [ ] `private_dns_enabled = true` on all interface endpoints — confirmed in describe output
- [ ] DNS check: `bedrock-runtime.eu-central-1.amazonaws.com` resolves to a 10.x.x.x address from within VPC
- [ ] `execute-api` endpoint ID appears in `terraform output endpoint_ids` — needed by Team 0's private API Gateway

### Effort Estimate

**Day -1** — 20 minutes (endpoints are declarative, just apply)

### Key Pitfalls

- Interface endpoints provision ENIs in each subnet — if subnets don't exist yet, endpoint creation fails; always apply T0-03 first
- `private_dns_enabled = true` requires the VPC to have `enableDnsSupport = true` and `enableDnsHostnames = true` — both set in T0-03
- Gateway endpoints (S3, DynamoDB) are attached to route tables, not subnets; confirm the private route table ID is referenced correctly
- The `execute-api` endpoint is needed for **private** API Gateway only; Team 0's API Gateway must be type `PRIVATE` and include this endpoint ID in its endpoint configuration

---

## TICKET T0-05 — Internal ALB Skeleton

### Goal

Provision the internal Application Load Balancer with a default listener returning `503 Service not yet configured`. Team 1 will add listener rules and target groups on top of this skeleton; neither team touches the ALB resource itself.

### What's Already Written

[terraform/modules/networking/main.tf](../../terraform/modules/networking/main.tf) already provisions:
- `aws_lb.internal` — internal=true, type=application, private subnets
- `aws_lb_listener.http` — port 80, default fixed-response 503
- `aws_security_group.alb` — inbound 443+80 from `10.0.0.0/8`, egress to VPC only

### Missing: HTTPS Listener

The current setup only has an HTTP listener on port 80. The Cognito `authenticate-cognito` action (M1-01) **requires HTTPS**. Two options:

**Option A — HTTP only for the hackathon (fast, no cert needed):**
Leave as-is. Team 1 adds listener rules to the port 80 listener. Cognito auth is skipped for Day 1–2, added on Day 3.

**Option B — HTTPS with self-signed cert (recommended):**

```hcl
# Self-signed TLS certificate (acceptable for internal/hackathon use)
resource "tls_private_key" "alb" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_self_signed_cert" "alb" {
  private_key_pem = tls_private_key.alb.private_key_pem

  subject {
    common_name  = data.terraform_remote_state.shared.outputs.alb_dns_name
    organization = "Accenture BG Hackathon"
  }

  validity_period_hours = 168  # 7 days

  allowed_uses = ["key_encipherment", "digital_signature", "server_auth"]
}

resource "aws_acm_certificate" "alb" {
  private_key      = tls_private_key.alb.private_key_pem
  certificate_body = tls_self_signed_cert.alb.cert_pem
}

resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.internal.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = aws_acm_certificate.alb.arn

  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "Service not yet configured"
      status_code  = "503"
    }
  }
}
```

Add the `hashicorp/tls` provider to `shared/main.tf`:

```hcl
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}
```

Export the HTTPS listener ARN for Team 1:

```hcl
# In shared/outputs.tf — update alb_listener_arn to the HTTPS listener
output "alb_listener_arn" {
  description = "ARN of the HTTPS listener (Team 1 adds rules here)"
  value       = aws_lb_listener.https.arn   # was http, now https
}
```

### Acceptance Criteria

- [ ] `aws elbv2 describe-load-balancers --names knowledge-base-internal-alb` shows `State.Code: active` and `Scheme: internal`
- [ ] `aws elbv2 describe-listeners --load-balancer-arn <arn>` shows listeners on port 80 (and 443 if Option B)
- [ ] Hitting the ALB DNS name from within the VPC returns HTTP 503 (not connection refused)
- [ ] ALB is in private subnets — confirm `Scheme: internal` and subnets are the private ones
- [ ] `terraform output alb_listener_arn` returns a non-empty ARN
- [ ] `terraform output alb_dns_name` returns the ALB DNS name — share with Team 1 for Cognito callback URL

### Effort Estimate

**Day -1** — 15 minutes (already written; only add HTTPS listener if using Option B)

---

## TICKET T0-06 — Bedrock Model Access + SES Production Access

### Goal

Manually enable the required Bedrock foundation models and request SES production access. Both are AWS Console operations that cannot be Terraformed and can take time to process — do them as early as possible.

### Bedrock Model Access

Navigate to: **AWS Console → Amazon Bedrock → Model access → eu-central-1**

Enable these models (click "Manage model access"):

| Model | Provider | Needed by | Notes |
|-------|----------|-----------|-------|
| Titan Text Embeddings V2 | Amazon | Team 0 (KB embeddings) | Usually instant |
| Claude 3.5 Sonnet v2 | Anthropic | Team 1 (Agent + responses) | Requires Anthropic ToS acceptance |
| Claude 3 Haiku | Anthropic | Optional fallback | Faster/cheaper |

```bash
# Verify after enabling:
aws bedrock list-foundation-models --region eu-central-1 \
  --query "modelSummaries[?contains(modelId, 'titan-embed') || contains(modelId, 'claude-3-5')].{id:modelId,status:modelLifecycle.status}"
```

Expected output:
```json
[
  {"id": "amazon.titan-embed-text-v2:0", "status": "ACTIVE"},
  {"id": "anthropic.claude-3-5-sonnet-20241022-v2:0", "status": "ACTIVE"}
]
```

### SES: Move Out of Sandbox

By default, new AWS accounts are in SES sandbox — only verified email addresses can be recipients. Two options:

**Option A — Verify individual emails (fast, sandbox stays):**

```bash
# Verify each participant's email (they receive a verification link)
aws ses verify-email-identity --email-address zoltan.szilagyi@accenture.com --region eu-central-1
aws ses verify-email-identity --email-address aigul@accenture.com --region eu-central-1
# Repeat for all participants
```

**Option B — Request production access (takes 24h, do Day -2):**

1. AWS Console → Amazon SES → Account dashboard → Request production access
2. Mail type: Transactional
3. Use case: Internal corporate notification system
4. Expected volume: <100 emails/day
5. Describe: Weekly knowledge base digest to internal Accenture team

```bash
# Verify SES sending quota after production access granted:
aws ses get-send-quota --region eu-central-1
# Should show SendMaxPerSecond and Max24HourSend > 200 (sandbox = 200)
```

### Acceptance Criteria

- [ ] `aws bedrock list-foundation-models` confirms `amazon.titan-embed-text-v2:0` is `ACTIVE`
- [ ] `aws bedrock list-foundation-models` confirms `anthropic.claude-3-5-sonnet-20241022-v2:0` is `ACTIVE`
- [ ] SES: `aws ses verify-email-identity` sent to all participants; each confirms the link
- [ ] SES test: `aws ses send-email --from <sender> --to <recipient> --subject "test" --body "test"` succeeds (no MessageRejected error)
- [ ] If using Anthropic models: Anthropic Terms of Service accepted in the Bedrock console

### Effort Estimate

**Day -2** — 30 minutes (models: instant; SES production request: submit and wait 24h)

---

## TICKET T0-07 — Endpoint Verification + Day 1 Readiness

### Goal

Run the pre-built verification Lambda from inside the VPC to confirm all PrivateLink endpoints resolve to private IPs and all AWS service calls succeed. Fix any failures before participants arrive. Destroy verification resources after a clean pass.

### What's Already Written

[terraform/shared/verify-endpoints/](../../terraform/shared/verify-endpoints/) is a self-contained Terraform module that:
- Deploys a Lambda function inside the private subnet
- Tests STS, S3, DynamoDB, Bedrock, Textract, ECR, CloudWatch Logs via their respective endpoints
- Performs DNS resolution checks for all interface endpoints
- Returns a `all_endpoints_reachable: true/false` summary

### Apply + Run + Destroy

```bash
cd terraform/shared/verify-endpoints

terraform init
terraform apply   # deploys verification Lambda (~30 seconds)

# Invoke the Lambda and capture output
aws lambda invoke \
  --function-name knowledge-base-verify-endpoints \
  --region eu-central-1 \
  --log-type Tail \
  --query 'LogResult' \
  --output text \
  /dev/stdout | base64 -d

# Expected final line:
# "all_endpoints_reachable": true

# Clean up after a clean pass
terraform destroy
```

### Interpreting Results

```json
{
  "all_endpoints_reachable": true,
  "region": "eu-central-1",
  "results": {
    "sts":               {"status": "OK", "detail": "Account: 064453091991, Role: ..."},
    "s3":                {"status": "OK", "detail": "Found 3 buckets"},
    "dynamodb":          {"status": "OK", "detail": "Found 1 tables"},
    "bedrock_runtime":   {"status": "OK", "detail": "Found 42 text models"},
    "textract":          {"status": "OK", "detail": "Endpoint reachable (expected validation error)"},
    "ecr":               {"status": "OK", "detail": "Endpoint reachable (no repos yet)"},
    "cloudwatch_logs":   {"status": "OK", "detail": "Endpoint reachable, found 1 log groups"},
    "dns_resolution": {
      "bedrock-runtime":       {"status": "OK", "ip": "10.0.10.5",  "private": true},
      "bedrock-agent-runtime": {"status": "OK", "ip": "10.0.11.8",  "private": true},
      "ecr.api":               {"status": "OK", "ip": "10.0.10.12", "private": true},
      "ecr.dkr":               {"status": "OK", "ip": "10.0.11.3",  "private": true},
      "logs":                  {"status": "OK", "ip": "10.0.10.9",  "private": true},
      "sts":                   {"status": "OK", "ip": "10.0.11.14", "private": true},
      "textract":              {"status": "OK", "ip": "10.0.10.7",  "private": true}
    }
  }
}
```

**Any `"status": "FAIL"`** or DNS resolving to a public IP must be fixed before Day 1.

### Common Failures and Fixes

| Failure | Likely cause | Fix |
|---------|-------------|-----|
| `sts: FAIL — Connection timeout` | STS endpoint missing or SG blocks 443 | Apply T0-04; check VPC endpoints SG allows inbound 443 from `10.0.0.0/16` |
| `bedrock_runtime: FAIL — not authorized` | Bedrock model access not enabled | Complete T0-06 model access |
| DNS resolves to `52.x.x.x` (public IP) | `private_dns_enabled = false` on endpoint | Set to `true` and re-apply |
| `ecr: FAIL — Connection timeout` | Missing `ecr.api` or `ecr.dkr` endpoint | Both must be present; apply T0-04 |
| Lambda fails to start | Lambda SG has no egress to VPC endpoints | Check lambda SG allows egress 443 to VPC CIDR |
| `textract: FAIL — not authorized` | Textract model access | Enable in Bedrock console (or IAM) |

### Day 1 Readiness Checklist

Run this checklist at **08:30 on Day 1** (30 min before kickoff):

```
PRE-HACKATHON CHECKS
====================

Infrastructure
  [ ] terraform/backend      — applied, state bucket exists
  [ ] terraform/shared       — applied, networking + endpoints + ALB all green
  [ ] verify-endpoints       — Lambda ran clean, all_endpoints_reachable: true
  [ ] verify-endpoints       — terraform destroy completed (save cost)

Access
  [ ] All 6 participants have working AWS CLI profiles (aws sts get-caller-identity passes)
  [ ] GitHub repo accessible to all participants (clone + push permissions verified)
  [ ] team0/ directory: terraform init succeeds for Team 0 member
  [ ] team1/ directory: terraform init succeeds for Team 1 member

Bedrock
  [ ] amazon.titan-embed-text-v2:0 — ACTIVE in eu-central-1
  [ ] anthropic.claude-3-5-sonnet-20241022-v2:0 — ACTIVE in eu-central-1

SES
  [ ] Sender email verified
  [ ] At least one recipient email verified (or production access granted)

Shared Outputs (paste these into the kickoff Slack channel)
  [ ] vpc_id:              vpc-xxxxxxxxxxxxxxxxx
  [ ] private_subnet_ids: ["subnet-xxxx", "subnet-yyyy"]
  [ ] alb_dns_name:       knowledge-base-internal-alb-xxxxxxxxx.eu-central-1.elb.amazonaws.com
  [ ] alb_listener_arn:   arn:aws:elasticloadbalancing:...

Cost Estimate (4-day hackathon)
  [ ] Interface VPC endpoints: ~€18 (9 endpoints × 2 AZs × 4 days)
  [ ] NAT Gateway: €0 (disabled)
  [ ] ALB: ~€2/day
  [ ] Bedrock: pay-per-use (estimate €5–15 for hackathon traffic)
  [ ] ECS Fargate (Team 1): ~€1/day for 1 vCPU task
  [ ] Total estimate: ~€50–80 for the full hackathon
```

### Acceptance Criteria

- [ ] Verify-endpoints Lambda returns `"all_endpoints_reachable": true`
- [ ] All DNS checks show `"private": true` (IPs in `10.x.x.x` range)
- [ ] Verification Lambda and its resources are **destroyed** after a clean pass
- [ ] Day 1 readiness checklist is fully green at 08:30
- [ ] Shared output values posted to the team communication channel before kickoff

### Effort Estimate

**Day -1 evening** — Apply T0-03 through T0-05, run verification, fix issues (1–2 hours total)
**Day 1 morning 08:30** — Final readiness check (15 minutes)

---

## Full Apply Sequence (Copy-Paste)

Run this on Day -1. Each step must succeed before the next:

```bash
# Step 1 — State backend (run once; local state)
cd terraform/backend
terraform init && terraform apply -auto-approve

# Step 2 — Shared networking + endpoints + ALB
cd ../shared
terraform init
terraform plan   # review ~35 resources
terraform apply

# Step 3 — Endpoint verification
cd verify-endpoints
terraform init && terraform apply -auto-approve
aws lambda invoke \
  --function-name knowledge-base-verify-endpoints \
  --region eu-central-1 \
  response.json && cat response.json | python3 -m json.tool | grep all_endpoints

# If all_endpoints_reachable == true:
terraform destroy -auto-approve
cd ../..

echo "Shared infrastructure ready. Participants can now run terraform init in team0/ and team1/"
```

---

## What Team 0 Does NOT Do

- Does not create Team 0 or Team 1 application resources (S3, Lambda, Bedrock KB, Cognito, ECS)
- Does not push any Docker images to ECR
- Does not configure Bedrock Knowledge Bases (Team 0 owns that)
- Does not deploy the ALB listener rules (Team 1 owns those)
- Does not write the metadata schema — that is agreed by all teams at Day 1 kickoff
