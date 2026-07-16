# Hackathon Requirements

## Overview

A 4-day intensive hackathon for ~10 participants (7 confirmed) to build an enterprise knowledge base with an AI agent on AWS, using Terraform for all infrastructure.

---

## Technical Requirements

### AWS Services (Milestone 0 — Foundation)

| Service | Purpose |
|---------|---------|
| S3 | Document storage (landing bucket + processed) |
| Amazon S3 Vector Store | Vector database for embeddings |
| Bedrock Knowledge Bases | Managed ingestion, chunking, embedding, retrieval |
| Bedrock (Claude Sonnet) | LLM for agent reasoning |
| Titan Text V2 Embeddings | Semantic vectorization (managed by Bedrock KB) |
| DynamoDB | Memory, sessions, feedback logs |
| Lambda | API layer + ingestion logic |
| API Gateway | REST API frontend |
| EventBridge | Scheduled weekly digest |
| SES | Email delivery for knowledge digest |
| CloudWatch | Monitoring & logging |
| Cognito | Authentication (Entra ID integration) |
| VPC + PrivateLink | Network isolation, no public endpoints |
| ALB (Internal) | Load balancing behind VPN |

### AWS Services (Milestone 1 — Chat Interface)

| Service | Purpose |
|---------|---------|
| ECS Fargate | Container hosting for chat UI |
| ECR | Docker image registry |
| Open WebUI (or equivalent) | Chat frontend |
| Bedrock Agents (Tool-Use) | Agentic routing with metadata filtering |

---

## Infrastructure Requirements

- **IaC Tool**: Terraform (mandatory — learning objective)
- **State Backend**: S3 + DynamoDB for remote state locking
- **Repository**: GitHub (monorepo with module structure)
- **CI/CD**: GitHub Actions for plan/apply pipelines
- **Environment**: Single AWS account with IAM boundaries per squad

---

## Functional Requirements (Milestone 0)

1. **Secure Document Ingestion**
   - Presigned URL generation for upload
   - Automatic `.metadata.json` sidecar creation
   - Multi-attribute tagging (Industry, Project, Type)

2. **Automated Text Extraction**
   - S3 event trigger on upload
   - OCR/text extraction via Bedrock Knowledge Bases

3. **Semantic Vectorization**
   - Titan Text V2 embedding
   - Vectors stored in S3 Vector Store with metadata

4. **Metadata-Aware Retrieval**
   - Filtered vector search by metadata attributes
   - Prevents cross-client data leakage

5. **Governance & Reporting**
   - EventBridge scheduled weekly Lambda
   - S3 bucket audit + SES email digest

---

## Functional Requirements (Milestone 1)

1. **Authentication Flow**
   - VPN → Internal ALB → Cognito → Entra ID SSO
   - Token validation before container access

2. **Chat Interface**
   - Open WebUI on ECS Fargate
   - Grounded responses with source citations

3. **Agentic Routing**
   - Bedrock Agent with tool-use for knowledge retrieval
   - Metadata filter passed to vector store

---

## Non-Functional Requirements

- All traffic behind corporate VPN (no public endpoints)
- PrivateLink for all internal AWS service communication
- All data classified as highly sensitive/restricted
- IAM least-privilege for all roles
- CloudWatch alarms for Lambda errors, API latency
- Terraform modules must be reusable and documented

---

## Assumptions

- ~50GB initial PDF/PowerPoint payload (digitally created, no scanned docs)
- Flat metadata taxonomy already defined (Industry, Project, Client, Type)
- Standard SAML/OIDC pattern for ALB ↔ Entra ID
- AIR ID registration assumed non-blocking
- S3 Vectors chosen over Aurora/pgvector to reduce operational overhead
