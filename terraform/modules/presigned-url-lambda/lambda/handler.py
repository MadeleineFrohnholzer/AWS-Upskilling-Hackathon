import json
import boto3
import os
from datetime import datetime, timezone

s3 = boto3.client("s3")

BUCKET = os.environ["LANDING_BUCKET"]
EXPIRY = int(os.environ.get("PRESIGNED_URL_EXPIRY_SECONDS", "1800"))

VALID_INDUSTRY = {
    "FSI",
    "PRD - Automotive",
    "PRD - Life Science",
    "PRD - Industrial",
    "PRD - Consumer Goods",
    "CMT",
    "H&PS",
    "RES",
    "Other",
}
VALID_DOCUMENT_TYPE = {
    "Architecture",
    "Discussion Deck",
    "RFP",
    "Proposal",
    "PoC",
    "Case Study",
    "Statement of Work (SOW)",
    "Assessment / Diagnostic",
    "Roadmap",
    "Runbook",
    "Executive Summary",
    "Point of View / Whitepaper",
    "Other",
}
VALID_USE_CASE = {
    "DB Migration",
    "Cloud Migration",
    "Data & Analytics Platform",
    "GenAI / AI Agent",
    "Application Modernization",
    "Cybersecurity",
    "ERP Implementation",
    "Infrastructure Optimization / FinOps",
    "DevOps / Platform Engineering",
    "Digital Transformation",
    "Managed Services",
    "Disaster Recovery / Resilience",
    "Other",
}
OPTIONAL_FIELDS = ("UseCase", "Client", "UploadedBy", "UploadedAt")


def _validate(body):
    errors = []

    filename = (body.get("filename") or "").strip()
    if not filename:
        errors.append("'filename' is required")

    industry = body.get("Industry")
    if not industry:
        errors.append("'Industry' is required")
    elif industry not in VALID_INDUSTRY:
        errors.append(f"'Industry' must be one of: {sorted(VALID_INDUSTRY)}")

    doc_type = body.get("DocumentType")
    if not doc_type:
        errors.append("'DocumentType' is required")
    elif doc_type not in VALID_DOCUMENT_TYPE:
        errors.append(f"'DocumentType' must be one of: {sorted(VALID_DOCUMENT_TYPE)}")

    use_case = body.get("UseCase")
    if use_case and use_case not in VALID_USE_CASE:
        errors.append(f"'UseCase' must be one of: {sorted(VALID_USE_CASE)}")

    return errors, filename, industry, doc_type


def handler(event, _context):
    try:
        body = json.loads(event.get("body") or "{}")
    except (json.JSONDecodeError, ValueError):
        return _resp(400, {"errors": ["Invalid JSON body"]})

    errors, filename, industry, doc_type = _validate(body)
    if errors:
        return _resp(400, {"errors": errors})

    metadata = {"Industry": industry, "DocumentType": doc_type}
    for field in OPTIONAL_FIELDS:
        if field in body:
            metadata[field] = body[field]
    if "UploadedAt" not in metadata:
        metadata["UploadedAt"] = datetime.now(timezone.utc).isoformat()

    metadata_key = f"{filename}.metadata.json"
    s3.put_object(
        Bucket=BUCKET,
        Key=metadata_key,
        Body=json.dumps(metadata, indent=2),
        ContentType="application/json",
    )

    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={"Bucket": BUCKET, "Key": filename},
        ExpiresIn=EXPIRY,
    )

    return _resp(200, {
        "upload_url": upload_url,
        "filename": filename,
        "metadata_key": metadata_key,
        "expires_in_seconds": EXPIRY,
    })


def _resp(status_code, body):
    return {
        "statusCode": status_code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(body),
    }
