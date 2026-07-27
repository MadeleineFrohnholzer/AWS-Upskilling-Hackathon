import boto3
import json
import os
from collections import defaultdict
from datetime import datetime, timezone, timedelta

dynamodb      = boto3.resource("dynamodb")
ses           = boto3.client("ses")
bedrock_agent = boto3.client("bedrock-agent")

DOCUMENTS_TABLE  = os.environ["DOCUMENTS_TABLE"]
DIGEST_RECIPIENT = os.environ["DIGEST_RECIPIENT"]
DIGEST_SENDER    = os.environ["DIGEST_SENDER"]
BEDROCK_KB_ID    = os.environ.get("BEDROCK_KB_ID", "")

def handler(event, context):
    # Optionally trigger a KB sync before reporting
    if BEDROCK_KB_ID:
        try:
            bedrock_agent.start_ingestion_job(knowledgeBaseId=BEDROCK_KB_ID,
                                              dataSourceId=os.environ.get("BEDROCK_DS_ID", ""))
        except Exception as e:
            print(f"KB sync skipped: {e}")

    table        = dynamodb.Table(DOCUMENTS_TABLE)
    one_week_ago = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()

    response = table.scan()
    all_docs = response.get("Items", [])

    recent_docs = [d for d in all_docs if d.get("uploaded_at", "") >= one_week_ago]
    by_industry = defaultdict(int)
    by_type     = defaultdict(int)
    for doc in all_docs:
        by_industry[doc.get("industry", "Other")] += 1
        by_type[doc.get("type", "Other")]         += 1

    kb_status = "N/A"
    if BEDROCK_KB_ID:
        try:
            kb_status = bedrock_agent.get_knowledge_base(
                knowledgeBaseId=BEDROCK_KB_ID)["knowledgeBase"]["status"]
        except Exception:
            pass

    body = _build_body(recent_docs, by_industry, by_type, len(all_docs), kb_status)
    subject = f"[AABG Knowledge Base] Weekly Digest — {datetime.now(timezone.utc).strftime('%Y-%m-%d')}"

    ses.send_email(
        Source=DIGEST_SENDER,
        Destination={"ToAddresses": [DIGEST_RECIPIENT]},
        Message={
            "Subject": {"Data": subject},
            "Body":    {"Text": {"Data": body}}
        }
    )
    print(f"Digest sent to {DIGEST_RECIPIENT}")
    return {"statusCode": 200, "body": "Digest sent"}

def _build_body(recent_docs, by_industry, by_type, total, kb_status):
    lines = [
        f"Documents indexed this week: {len(recent_docs)}",
        "",
        "By Industry:"
    ]
    for ind, cnt in sorted(by_industry.items(), key=lambda x: -x[1]):
        lines.append(f"  {ind:<20} {cnt}")
    lines += ["", "By Type:"]
    for t, cnt in sorted(by_type.items(), key=lambda x: -x[1]):
        lines.append(f"  {t:<20} {cnt}")
    lines += ["", "Recent uploads (last 7 days):"]
    for doc in sorted(recent_docs, key=lambda d: d.get("uploaded_at", ""), reverse=True)[:10]:
        lines.append(
            f"  - {doc['filename']}  "
            f"({doc.get('industry','?')} / {doc.get('type','?')}, "
            f"uploaded by {doc.get('uploaded_by','unknown')})"
        )
    lines += [
        "",
        f"Total documents indexed: {total}",
        f"Knowledge Base status:   {kb_status}",
        "",
        "---",
        "Sent automatically by the AABG Knowledge Platform."
    ]
    return "\n".join(lines)
