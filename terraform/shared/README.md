# Shared Infrastructure

Pre-provisioned VPC, networking, VPC endpoints, and ALB skeleton. Both teams consume these outputs via `terraform_remote_state`.

## What's included

| Resource | Purpose |
|----------|---------|
| VPC (10.0.0.0/16) | Foundational network for all workloads |
| Public subnets (2 AZs) | ALB, NAT Gateway (if enabled) |
| Private subnets (2 AZs) | Lambda, ECS Fargate |
| S3 Gateway Endpoint | Free, no NAT dependency |
| DynamoDB Gateway Endpoint | Free, no NAT dependency |
| Bedrock Runtime Interface Endpoint | Model invocation via PrivateLink |
| Bedrock Agent Runtime Interface Endpoint | Agent invocation via PrivateLink |
| Textract Interface Endpoint | OCR via PrivateLink |
| ECR API + Docker Interface Endpoints | Fargate image pulls via PrivateLink |
| CloudWatch Logs Interface Endpoint | Log shipping via PrivateLink |
| STS Interface Endpoint | Role assumption via PrivateLink |
| Internal ALB (skeleton) | Empty target groups, Team 2 attaches service |
| Baseline Security Groups | Lambda SG, ECS SG, ALB SG, VPCE SG |

## Provisioning Order

```bash
# 1. State backend (one-time)
cd ../backend
terraform init && terraform apply

# 2. Shared networking
cd ../shared
terraform init && terraform apply

# 3. Verify endpoints work
cd verify-endpoints
terraform init && terraform apply

# Invoke the test Lambda:
aws lambda invoke --function-name knowledge-base-verify-endpoints \
  --profile hackathon /dev/stdout

# 4. Clean up verification resources (optional, saves cost)
terraform destroy
```

## Verification Lambda

The `verify-endpoints/` directory contains a test Lambda that runs inside the VPC private subnet and checks:

- STS: Can assume roles (PrivateLink)
- S3: Can list buckets (Gateway endpoint)
- DynamoDB: Can list tables (Gateway endpoint)
- Bedrock: Can list models (PrivateLink)
- Textract: Endpoint reachable (PrivateLink)
- ECR: Can describe repos (PrivateLink)
- CloudWatch Logs: Can describe log groups (PrivateLink)
- DNS resolution: All endpoints resolve to private IPs

Expected output when everything works:

```json
{
  "all_endpoints_reachable": true,
  "region": "eu-central-1",
  "results": { "sts": {"status": "OK"}, ... }
}
```

## NAT Gateway

Disabled by default (`enable_nat_gateway = false`). Only enable if:
- A service genuinely needs outbound internet access
- You need to pull Docker images from public registries (Docker Hub)

Since all AWS services are covered by PrivateLink endpoints, and container images come from ECR (also via PrivateLink), NAT is typically not needed.

## Outputs (consumed by teams)

```hcl
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket = "hackathon-tf-state-<account-id>"
    key    = "shared/terraform.tfstate"
    region = "eu-central-1"
  }
}

# Then use:
# data.terraform_remote_state.shared.outputs.vpc_id
# data.terraform_remote_state.shared.outputs.private_subnet_ids
# data.terraform_remote_state.shared.outputs.lambda_security_group_id
# data.terraform_remote_state.shared.outputs.ecs_tasks_security_group_id
# data.terraform_remote_state.shared.outputs.alb_arn
# etc.
```
