# Metadata Schema — Shared Contract

This schema defines the metadata fields stored alongside every document vector. Both teams MUST agree on this before implementation.

**Team 1** writes metadata in this format during ingestion.
**Team 2** filters by these fields during retrieval.

## Fields

| Field | Type | Required | Values |
|-------|------|----------|--------|
| `Industry` | string | **Yes** | Banking, Automotive, Healthcare, Energy, Retail, Technology, Insurance, Telecom, Other |
| `Type` | string | **Yes** | PoC, RFP, Case Study, Proposal, Architecture, Strategy, Report, Other |
| `Project` | string | No | Internal project codename (e.g., Titan, Phoenix) |
| `Client` | string | No | Client identifier for internal filtering |
| `Topic` | string | No | Sales, Engineering, Strategy, Operations, HR, Finance, Other |
| `UploadedBy` | string | No | Email or username of the uploader |
| `UploadedAt` | ISO 8601 | No | Timestamp of upload |

## Example Sidecar File

Every uploaded document gets a `.metadata.json` sidecar:

```json
{
  "Industry": "Banking",
  "Type": "Case Study",
  "Project": "Titan",
  "Topic": "Sales",
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
      { "equals": { "key": "Industry", "value": "Banking" } },
      { "equals": { "key": "Type", "value": "Case Study" } }
    ]
  }
}
```

## Rules

1. `Industry` and `Type` are mandatory — every document must have them
2. Values must match the enum lists exactly (case-sensitive)
3. If a document doesn't fit any enum value, use "Other"
4. The schema can be extended during the hackathon if both teams agree
