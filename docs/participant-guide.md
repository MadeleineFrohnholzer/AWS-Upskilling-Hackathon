# Participant Guide — AWS Knowledge Base Hackathon

Welcome! Over 4 days we'll build an enterprise-grade AI knowledge base on AWS, using Terraform for all infrastructure. This guide gets you set up before Day 1.

---

## What We're Building

An internal AI-powered knowledge platform that:
- Ingests PDFs/documents with metadata tagging
- Vectorizes content for semantic search
- Provides a chat interface backed by Claude (Bedrock) with grounded, cited answers
- Runs entirely behind corporate VPN with enterprise auth

**Architecture:** See the architecture diagrams in the screenshot folder.

---

## Pre-Hackathon Setup Checklist

### 1. Laptop Requirements

| Tool | Version | Install |
|------|---------|---------|
| Terraform | ≥ 1.7 | `brew install terraform` or [terraform.io/downloads](https://developer.hashicorp.com/terraform/downloads) |
| AWS CLI v2 | ≥ 2.15 | `brew install awscli` or [docs.aws.amazon.com](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) |
| Git | ≥ 2.40 | `brew install git` |
| Docker Desktop | Latest | [docker.com/products/docker-desktop](https://www.docker.com/products/docker-desktop/) |
| VS Code (recommended) | Latest | [code.visualstudio.com](https://code.visualstudio.com/) |
| Python 3.11+ | ≥ 3.11 | `brew install python@3.11` (for Lambda development) |
| Node.js 20+ | ≥ 20 | `brew install node@20` (optional, for frontend tooling) |

### Recommended VS Code Extensions
- HashiCorp Terraform
- AWS Toolkit
- Python
- Docker
- GitLens

### 2. AWS Access

You will receive:
- **AWS Account ID**: Shared hackathon account
- **IAM User credentials** or **SSO profile** (TBD by organizer)
- **Region**: `eu-central-1` (Frankfurt) — confirm with organizer

Configure your CLI:
```bash
# Option A: IAM credentials
aws configure --profile hackathon
# Enter Access Key, Secret Key, region: eu-central-1, output: json

# Option B: SSO (if provided)
aws configure sso --profile hackathon
```

Verify access:
```bash
aws sts get-caller-identity --profile hackathon
```

### 3. GitHub Repository Access

- Accept the GitHub repo invitation (link will be shared)
- Clone the repo:
  ```bash
  git clone https://github.com/<org>/AWS-Upskilling-Hackathon.git
  cd AWS-Upskilling-Hackathon
  ```
- Each squad works on feature branches, merges via PR

### 4. Terraform Backend (Pre-provisioned)

The remote state backend (S3 bucket + DynamoDB lock table) will be provisioned before Day 1. You'll configure it as:

```hcl
terraform {
  backend "s3" {
    bucket         = "hackathon-tf-state-064453091991"
    key            = "<team1|team2>/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "hackathon-tf-locks"
    encrypt        = true
  }
}
```

---

## DevOps Tooling

| Tool | Purpose |
|------|---------|
| Terraform | All infrastructure provisioning |
| GitHub Actions | CI/CD for `terraform plan` on PR, `terraform apply` on merge |
| AWS CloudWatch | Logs and monitoring |
| tflint | Terraform linting (optional but recommended) |
| checkov / tfsec | Security scanning for Terraform (optional) |

---

## Hackathon Overview

### Day 1 — Foundation & Networking
- Intro & architecture walkthrough
- Terraform basics workshop
- Squad formation
- Build: VPC, subnets, security groups, S3 buckets

### Day 2 — Ingestion Pipeline
- Build: Lambda functions, API Gateway, presigned URL flow
- Build: S3 event triggers, metadata handling
- Build: Bedrock Knowledge Base configuration

### Day 3 — Intelligence Layer
- Build: Vector store setup, embedding pipeline
- Build: DynamoDB tables (sessions, feedback)
- Build: EventBridge + digest Lambda

### Day 4 — Chat Interface & Integration
- Build: ECS Fargate cluster, ALB, container deployment
- Build: Bedrock Agent with tool-use
- Integration testing, demo prep
- Final presentations

---

## Terraform Conventions

```
terraform/
├── modules/           # Reusable modules
│   ├── networking/
│   ├── storage/
│   ├── compute/
│   └── ...
├── environments/
│   └── dev/           # Dev environment root
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
└── backend/           # State backend (pre-provisioned)
```

- Use **modules** for reusable components
- Use **variables** for all configurable values (no hardcoded ARNs)
- Use **outputs** to share values between modules
- Tag everything: `Project = "knowledge-base"`, `Environment = "dev"`, `Squad = "<your-squad>"`

---

## Useful Commands

```bash
# Initialize Terraform
terraform init

# Preview changes
terraform plan

# Apply changes
terraform apply

# Destroy (careful!)
terraform destroy

# Format code
terraform fmt -recursive

# Validate configuration
terraform validate
```

---

## Support & Communication

- **Slack/Teams channel**: TBD
- **AWS issues**: Reach out to organizer
- **Terraform help**: Pair with teammates, ask in channel
- **Architecture questions**: Refer to diagrams + this guide

---

## Resources

- [Terraform AWS Provider Docs](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS Bedrock Documentation](https://docs.aws.amazon.com/bedrock/)
- [Bedrock Knowledge Bases Guide](https://docs.aws.amazon.com/bedrock/latest/userguide/knowledge-base.html)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Open WebUI GitHub](https://github.com/open-webui/open-webui)
