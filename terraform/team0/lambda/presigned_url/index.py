import boto3
import json
import os
import uuid
from datetime import datetime, timezone

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

LANDING_BUCKET  = os.environ["LANDING_BUCKET"]
DOCUMENTS_TABLE = os.environ["DOCUMENTS_TABLE"]
PRESIGN_EXPIRY  = 900  # 15 minutes

VALID_INDUSTRIES = {"Banking", "Automotive", "Healthcare", "Energy", "Retail",
                    "Technology", "Insurance", "Telecom", "Other"}
VALID_TYPES      = {"PoC", "RFP", "Case Study", "Proposal", "Architecture",
                    "Strategy", "Report", "Other"}

def handler(event, context):
    try:
        body = json.loads(event.get("body") or "{}")
    except json.JSONDecodeError:
        return _error(400, "Invalid JSON body")

    filename    = body.get("filename", "").strip()
    industry    = body.get("industry", "Other")
    doc_type    = body.get("type", "Other")
    project     = body.get("project", "")
    topic       = body.get("topic", "")
    client      = body.get("client", "")
    uploaded_by = body.get("uploaded_by", "")

    if not filename:
        return _error(400, "filename is required")
    if industry not in VALID_INDUSTRIES:
        return _error(400, f"industry must be one of: {sorted(VALID_INDUSTRIES)}")
    if doc_type not in VALID_TYPES:
        return _error(400, f"type must be one of: {sorted(VALID_TYPES)}")

    document_id = str(uuid.uuid4())
    s3_key      = f"uploads/{document_id}/{filename}"
    uploaded_at = datetime.now(timezone.utc).isoformat()

    table = dynamodb.Table(DOCUMENTS_TABLE)
    table.put_item(Item={
        "document_id": document_id,
        "filename":    filename,
        "s3_key":      s3_key,
        "industry":    industry,
        "type":        doc_type,
        "project":     project,
        "topic":       topic,
        "client":      client,
        "uploaded_by": uploaded_by,
        "uploaded_at": uploaded_at,
        "status":      "PENDING_UPLOAD"
    })

    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket":      LANDING_BUCKET,
            "Key":         s3_key,
            "ContentType": "application/octet-stream"
        },
        ExpiresIn=PRESIGN_EXPIRY
    )

    return {
        "statusCode": 200,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps({
            "document_id": document_id,
            "upload_url":  upload_url,
            "s3_key":      s3_key,
            "expires_in":  PRESIGN_EXPIRY
        })
    }

def _error(code, message):
    return {
        "statusCode": code,
        "headers":    {"Content-Type": "application/json"},
        "body":       json.dumps({"error": message})
    }
