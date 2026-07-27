# 4-Day Sprint Plan — 2-Team Setup

## Team Structure

| Team | Focus | Members | Owns |
|------|-------|---------|------|
| **Team 0 — Foundation / Ingestion (M0)** | Upload → Indexed Vectors | Aigul, Zoltan, Sandro | S3, Lambda, Bedrock KB, DynamoDB, EventBridge, SES |
| **Team 1 — Access / Knowledge App (M1)** | Login → Cited Answer | Nikos, Yildrim, Nicolas | Cognito, ECS Fargate, Bedrock Agent, ALB integration |

> **Shared infrastructure** (VPC, networking, ALB skeleton) is pre-provisioned before Day 1. Both teams consume it via `terraform_remote_state`.

---

## Pre-Provisioned (Before Day 1)

Provisioned by organizers in `terraform/shared/`:

- VPC with private + public subnets across 2 AZs
- VPC Gateway Endpoints: S3, DynamoDB
- VPC Interface Endpoints (PrivateLink): Bedrock Runtime, Bedrock Agent Runtime, Textract, ECR, CloudWatch Logs, STS
- Internal ALB (skeleton — empty target groups)
- Baseline security groups (internal-only ingress)
- NAT Gateway (if needed for outbound internet)
- Terraform remote state backend (S3 + DynamoDB lock)

---

## Shared Contract: Metadata Schema

Both teams must agree on this **before** starting implementation. Define in `docs/metadata-schema.json`:

```json
{
  "Industry": "string (e.g., Banking, Automotive, Healthcare)",
  "Project": "string (e.g., Titan, Phoenix)",
  "Type": "string (e.g., PoC, RFP, Case Study, Proposal)",
  "Client": "string (optional, for internal filtering)",
  "Topic": "string (e.g., Sales, Engineering, Strategy)"
}
```

Team 0 writes metadata in this format → Team 1 queries with these filter keys.

---

## Day 1 — Foundation & First Resources

### Morning (9:00–12:00)

| Time | Activity | Who |
|------|----------|-----|
| 9:00–9:30 | Kickoff: Goals, architecture walkthrough, shared infra overview | All |
| 9:30–10:30 | **Terraform Workshop**: State, providers, resources, modules, plan/apply | All |
| 10:30–11:00 | Team formation + metadata schema agreement | All |
| 11:00–12:00 | Hands-on exercise: Deploy an S3 bucket via Terraform | All |

### Afternoon (13:00–17:00)

| Team | Tasks |
|------|-------|
| Team 0 | S3 landing bucket + processed bucket (encrypted, versioned), DynamoDB tables (metadata, sessions), IAM roles for Lambda |
| Team 1 | Cognito User Pool + Entra ID federation, ECR repository, ECS cluster + task definition skeleton |

### Day 1 Deliverables
- [ ] S3 buckets with encryption + public access block (Team 0)
- [ ] DynamoDB tables provisioned (Team 0)
- [ ] Cognito pool with Entra ID integration started (Team 1)
- [ ] ECS cluster + ECR repo created (Team 1)
- [ ] All infra in Terraform, per-team state files working

---

## Day 2 — Ingestion Pipeline & Container App

### Morning (9:00–12:00)

| Team | Tasks |
|------|-------|
| Team 0 | Lambda: presigned URL generator, Lambda: metadata sidecar creator, API Gateway REST endpoints |
| Team 1 | Dockerfile for Open WebUI (or equivalent), push to ECR, ECS Fargate service definition |

### Afternoon (13:00–17:00)

| Team | Tasks |
|------|-------|
| Team 0 | S3 event notification → Lambda trigger, Bedrock Knowledge Base resource, data source config, embedding pipeline |
| Team 1 | ECS service running on Fargate, attach to ALB target group, health checks, HTTPS listener |

### Day 2 Deliverables
- [ ] Working upload flow: presigned URL → S3 → metadata sidecar (Team 0)
- [ ] Bedrock KB configured + first ingestion test (Team 0)
- [ ] Chat container running on Fargate behind ALB (Team 1)
- [ ] API Gateway endpoints live (Team 0)

---

## Day 3 — Intelligence & Agent

### Morning (9:00–12:00)

| Team | Tasks |
|------|-------|
| Team 0 | Bedrock KB ingestion testing with sample docs, vector store verification, metadata filter queries, fix chunking issues |
| Team 1 | Bedrock Agent definition, tool-use schema for KB retrieval, system prompt design, metadata filter integration |

### Afternoon (13:00–17:00)

| Team | Tasks |
|------|-------|
| Team 0 | EventBridge weekly schedule, SES identity verification, digest Lambda (query S3, format report), CloudWatch dashboards |
| Team 1 | Agent ↔ Knowledge Base end-to-end test, citation rendering, error handling, auth flow verification (Cognito → ALB → ECS) |

### Day 3 Deliverables
- [ ] Documents ingestible and searchable via Bedrock KB with metadata filtering (Team 0)
- [ ] Weekly digest Lambda working (Team 0)
- [ ] Bedrock Agent answering questions with source citations (Team 1)
- [ ] Auth flow: Cognito → ALB → container working (Team 1)

---

## Day 4 — Integration & Demo

### Morning (9:00–12:00)

| Activity | Who |
|----------|-----|
| Full integration: Upload docs (Team 0) → Query via chat (Team 1) → Cited answer | All |
| Cross-team integration testing: metadata filter contract validation | All |
| Bug fixing, edge cases, error handling | All |
| Load real sample documents, verify metadata filtering works end-to-end | All |

### Afternoon (13:00–17:00)

| Time | Activity | Who |
|------|----------|-----|
| 13:00–14:30 | Polish, documentation, README updates per module | All |
| 14:30–15:30 | Demo prep (each team preps 5-min demo of their milestone) | Teams |
| 15:30–16:30 | **Final Demo** — end-to-end walkthrough | All |
| 16:30–17:00 | Retro: Lessons learned, what worked, what didn't | All |

### Day 4 Deliverables
- [ ] End-to-end: upload PDF → metadata tagged → vectorized → searchable via chat → cited answer
- [ ] All infrastructure in Terraform (no ClickOps)
- [ ] Documentation complete
- [ ] Demo delivered

---

## Integration Point (Cross-Team Contract)

The single integration boundary between teams:

```
Team 0 OUTPUTS (via terraform_remote_state):
  - bedrock_kb_id
  - bedrock_kb_arn
  - s3_vector_store_arn
  - landing_bucket_name (for upload URL generation)

Team 1 CONSUMES:
  - Bedrock KB ID → used in Agent tool-use configuration
  - Metadata filter schema → used in retrieval queries

Contract:
  - docs/metadata-schema.json defines the shared vocabulary
  - Team 0 guarantees vectors are stored with these metadata keys
  - Team 1 guarantees queries use only these metadata keys for filtering
```

---

## State File Layout

| State Key | Owner | Contents |
|-----------|-------|----------|
| `shared/terraform.tfstate` | Pre-provisioned | VPC, subnets, endpoints, ALB skeleton, base SGs |
| `team0/terraform.tfstate` | Team 0 | S3 buckets, Lambda, API GW, Bedrock KB, DynamoDB, EventBridge, SES |
| `team1/terraform.tfstate` | Team 1 | Cognito, ECS, ECR, Bedrock Agent, ALB target groups |

---

## Stretch Goals (If Time Permits)

- [ ] GitHub Actions CI/CD pipeline (plan on PR, apply on merge)
- [ ] tflint + checkov in CI
- [ ] Custom chunking strategy for Bedrock KB
- [ ] Feedback loop: thumbs up/down stored in DynamoDB
- [ ] Teams/Outlook integration via Graph API
- [ ] Multi-turn conversation memory (DynamoDB session store)

---

## Daily Standup Format (15 min, start of each day)

1. What did your team accomplish yesterday?
2. What's the plan for today?
3. Any blockers or cross-team dependencies?
4. Is the metadata schema contract still holding?

---

## Success Criteria

| Criterion | Target |
|-----------|--------|
| Terraform coverage | 100% of infrastructure (no manual console changes) |
| Milestone 0 complete | Upload → vectorized → searchable with metadata filters |
| Milestone 1 complete | Auth → chat → agent → KB → cited response |
| Integration | End-to-end flow works across both teams |
| Learning outcome | Every participant has authored and applied Terraform |
| Documentation | Each module has README + variable descriptions |
