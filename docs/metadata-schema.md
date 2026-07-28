# Metadata Schema — Shared Contract

This schema defines the metadata fields stored alongside every document vector. Both teams MUST agree on this before implementation.

**Team 1** writes metadata in this format during ingestion.
**Team 2** filters by these fields during retrieval.

## Fields

| Field | Type | Required | Values |
|-------|------|----------|--------|
| `Industry` | string | **Yes** | FSI, PRD - Automotive, PRD - Life Science, PRD - Industrial, PRD - Consumer Goods, CMT, H&PS, RES, Other |
| `DocumentType` | string | **Yes** | Architecture, Discussion Deck, RFP, Proposal, PoC, Case Study, Statement of Work (SOW), Assessment / Diagnostic, Roadmap, Runbook, Executive Summary, Point of View / Whitepaper, Other |
| `UseCase` | string | No | DB Migration, Cloud Migration, Data & Analytics Platform, GenAI / AI Agent, Application Modernization, Cybersecurity, ERP Implementation, Infrastructure Optimization / FinOps, DevOps / Platform Engineering, Digital Transformation, Managed Services, Disaster Recovery / Resilience, Other |
| `Client` | string | No | Client identifier for internal filtering |
| `UploadedAt` | ISO 8601 | No | Timestamp of upload |

## Example Sidecar File

Every uploaded document gets a `.metadata.json` sidecar:

```json
{
  "Industry": "FSI",
  "DocumentType": "Case Study",
  "UseCase": "Cloud Migration",
  "Client": "Acme Corp",
  "UploadedBy": "max.frohnholzer@accenture.com",
  "UploadedAt": "2026-07-16T10:30:00Z"
}
```

## Usage in Retrieval (Team 2)

When the Bedrock Agent queries the Knowledge Base, it passes metadata filters:

```json
{
  "filter": {
    "andAll": [
      { "equals": { "key": "Industry", "value": "FSI" } },
      { "equals": { "key": "DocumentType", "value": "Case Study" } }
    ]
  }
}
```

## Rules

1. `Industry` and `DocumentType` are mandatory — every document must have them
2. Values must match the enum lists exactly (case-sensitive)
3. If a document doesn't fit any enum value, use "Other"
4. The schema can be extended during the hackathon if both teams agree