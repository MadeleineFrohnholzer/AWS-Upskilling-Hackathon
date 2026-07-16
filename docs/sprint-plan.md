# 4-Day Sprint Plan & Squad Structure

## Squad Formation (7–10 people)

Split into 3 squads that work in parallel on different layers, then integrate.

| Squad | Focus | Size | Skills Emphasis |
|-------|-------|------|-----------------|
| **Alpha — Networking & Security** | VPC, ALB, Cognito, IAM | 2–3 | Networking, security, auth |
| **Bravo — Data & Intelligence** | S3, Bedrock KB, Vectors, Lambda, DynamoDB | 3–4 | Data engineering, serverless |
| **Charlie — Compute & Frontend** | ECS Fargate, Docker, Open WebUI, Bedrock Agent | 2–3 | Containers, frontend, LLM |

> **Note:** Squads are not silos. Cross-squad pairing is encouraged, especially for integration points.

---

## Day 1 — Foundation (All Squads)

### Morning (9:00–12:00)
| Time | Activity | Who |
|------|----------|-----|
| 9:00–9:30 | Kickoff: Goals, architecture overview, demo of end-state | All |
| 9:30–10:30 | **Terraform Workshop**: State, providers, resources, modules, plan/apply cycle | All |
| 10:30–11:00 | Squad formation + repo orientation | All |
| 11:00–12:00 | Hands-on: Each person deploys an S3 bucket via Terraform (hello-world exercise) | All |

### Afternoon (13:00–17:00)
| Squad | Tasks |
|-------|-------|
| Alpha | VPC with public/private subnets, NAT Gateway, security groups, VPC endpoints for S3/Bedrock |
| Bravo | S3 landing bucket + processed bucket, DynamoDB tables (sessions, feedback), IAM roles for Lambda |
| Charlie | ECR repository, ECS cluster definition, task definition skeleton, ALB (internal) |

### Day 1 Deliverables
- [ ] VPC with private subnets + VPC endpoints (Alpha)
- [ ] S3 buckets with encryption + lifecycle policies (Bravo)
- [ ] ECS cluster + ALB skeleton (Charlie)
- [ ] All infra in Terraform, state in remote backend

---

## Day 2 — Ingestion Pipeline

### Morning (9:00–12:00)
| Squad | Tasks |
|-------|-------|
| Alpha | Cognito User Pool + Entra ID integration, IAM policies for cross-service access |
| Bravo | Lambda: presigned URL generator, Lambda: metadata sidecar creator, API Gateway setup |
| Charlie | Dockerfile for Open WebUI, push to ECR, ECS service definition |

### Afternoon (13:00–17:00)
| Squad | Tasks |
|-------|-------|
| Alpha | API Gateway → Lambda integration, WAF rules (optional) |
| Bravo | S3 event notification → Lambda trigger, Bedrock Knowledge Base resource, data source configuration |
| Charlie | ECS Fargate service running, ALB target group + health checks |

### Day 2 Deliverables
- [ ] Working upload flow: presigned URL → S3 → metadata sidecar (Bravo)
- [ ] Cognito auth pool configured (Alpha)
- [ ] Open WebUI container running on Fargate (Charlie)
- [ ] API Gateway endpoints live (Alpha + Bravo)

---

## Day 3 — Intelligence Layer

### Morning (9:00–12:00)
| Squad | Tasks |
|-------|-------|
| Alpha | CloudWatch dashboards, alarms for Lambda errors + API latency |
| Bravo | Bedrock KB ingestion testing, vector store verification, metadata filter queries |
| Charlie | Bedrock Agent definition, tool-use schema for KB retrieval, system prompt design |

### Afternoon (13:00–17:00)
| Squad | Tasks |
|-------|-------|
| Alpha | EventBridge rule (weekly schedule), SES identity verification |
| Bravo | Weekly digest Lambda (query S3, format report), test with sample documents |
| Charlie | Agent ↔ Knowledge Base integration, citation formatting, end-to-end chat test |

### Day 3 Deliverables
- [ ] Documents ingestible and searchable via Bedrock KB (Bravo)
- [ ] Bedrock Agent answering questions with citations (Charlie)
- [ ] Monitoring dashboards live (Alpha)
- [ ] Weekly digest Lambda tested (Alpha + Bravo)

---

## Day 4 — Integration & Demo

### Morning (9:00–12:00)
| Activity | Who |
|----------|-----|
| Full integration: Auth → Chat UI → Agent → KB → Response | All |
| Bug fixing, edge cases, error handling | All |
| Load sample documents (real PDFs), test metadata filtering | Bravo + Charlie |
| Security review: IAM policies, SG rules, encryption | Alpha |

### Afternoon (13:00–17:00)
| Time | Activity | Who |
|------|----------|-----|
| 13:00–14:30 | Polish, documentation, README updates | All |
| 14:30–15:30 | Demo preparation (each squad preps 5-min demo of their layer) | Squads |
| 15:30–16:30 | **Final Demo** — end-to-end walkthrough | All |
| 16:30–17:00 | Retro: What we learned, what we'd do differently | All |

### Day 4 Deliverables
- [ ] End-to-end flow working (upload → search → chat → cited answer)
- [ ] All infrastructure in Terraform (no ClickOps!)
- [ ] Documentation complete
- [ ] Demo delivered

---

## Integration Points (Cross-Squad)

These are the critical handoff points where squads need to coordinate:

```
Alpha ←→ Bravo:
  - VPC endpoint IDs for Lambda/Bedrock access
  - IAM role ARNs for Lambda execution
  - API Gateway ↔ Lambda integration

Alpha ←→ Charlie:
  - ALB listener rules + target groups
  - Security group IDs for ECS tasks
  - Cognito pool ID + client ID

Bravo ←→ Charlie:
  - Bedrock KB ID + data source ID
  - Knowledge base ARN for Agent tool-use
  - Metadata filter schema agreement
```

**Recommendation:** Use Terraform outputs and data sources to share values between modules. Avoid hardcoding ARNs.

---

## Stretch Goals (If Time Permits)

- [ ] GitHub Actions CI/CD pipeline (plan on PR, apply on merge)
- [ ] tflint + checkov in CI
- [ ] Multi-environment setup (dev/staging)
- [ ] Custom chunking strategy for Bedrock KB
- [ ] Feedback loop: thumbs up/down stored in DynamoDB
- [ ] Teams/Outlook integration via Graph API

---

## Daily Standup Format (15 min, start of each day)

1. What did your squad accomplish yesterday?
2. What's the plan for today?
3. Any blockers or cross-squad dependencies?

---

## Success Criteria

| Criterion | Target |
|-----------|--------|
| Terraform coverage | 100% of infrastructure (no manual AWS console changes) |
| Milestone 0 complete | All 5 workflow steps functional |
| Milestone 1 (stretch) | Chat interface with agent answering questions |
| Learning outcome | Every participant has authored and applied Terraform |
| Documentation | Each module has README + variable descriptions |
