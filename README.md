# AWS Knowledge Base Hackathon

A 4-day intensive hackathon to build an enterprise AI knowledge base on AWS using Terraform.

## Quick Links

- [Participant Guide](docs/participant-guide.md) — Setup instructions and hackathon overview
- [Requirements](docs/requirements.md) — Technical and functional requirements
- [Sprint Plan](docs/sprint-plan.md) — Day-by-day schedule and squad structure

## Repository Structure

```
.
├── docs/                          # Documentation
│   ├── participant-guide.md       # Pre-hackathon setup guide
│   ├── requirements.md            # Full requirements document
│   └── sprint-plan.md             # 4-day plan + squad breakdown
├── terraform/
│   ├── backend/                   # State backend (pre-provision before hackathon)
│   ├── modules/
│   │   ├── networking/            # VPC, subnets, VPC endpoints
│   │   ├── storage/               # S3 buckets, DynamoDB tables
│   │   └── compute/               # ECS Fargate, ALB, ECR
│   └── environments/
│       └── dev/                   # Dev environment root
└── product.txt                    # Product specification
```

## Getting Started

1. Read the [Participant Guide](docs/participant-guide.md)
2. Install prerequisites (Terraform, AWS CLI, Docker)
3. Configure AWS credentials
4. Clone this repo and run `terraform init` from `terraform/environments/dev/`

## Architecture

The platform consists of two milestones:
- **Milestone 0 (Foundation):** Document ingestion, vectorization, metadata-aware storage, weekly digest
- **Milestone 1 (Chat):** Authenticated chat interface with Bedrock Agent for grounded Q&A
