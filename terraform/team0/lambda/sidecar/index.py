import boto3
import json
import os
import urllib.parse
from datetime import datetime, timezone

s3            = boto3.client("s3")
dynamodb      = boto3.resource("dynamodb")
bedrock_agent = boto3.client("bedrock-agent")

PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
DOCUMENTS_TABLE  = os.environ["DOCUMENTS_TABLE"]
BEDROCK_KB_ID    = os.environ.get("BEDROCK_KB_ID", "")
BEDROCK_DS_ID    = os.environ.get("BEDROCK_DS_ID", "")

def handler(event, context):
    for record in event["Records"]:
        bucket  = record["s3"]["bucket"]["name"]
        s3_key  = urllib.parse.unquote_plus(record["s3"]["object"]["key"])

        if s3_key.endswith(".metadata.json"):
            print(f"Skipping sidecar: {s3_key}")
            continue

        print(f"Processing: s3://{bucket}/{s3_key}")
        _process(bucket, s3_key)

def _process(bucket, s3_key):
    table = dynamodb.Table(DOCUMENTS_TABLE)

    parts       = s3_key.split("/")
    document_id = parts[1] if len(parts) >= 3 else None

    item = {}
    if document_id:
        item = table.get_item(Key={"document_id": document_id}).get("Item", {})

    metadata = {
        "metadataAttributes": {
            "Industry":   {"type": "STRING", "value": item.get("industry", "Other")},
            "Type":       {"type": "STRING", "value": item.get("type", "Other")},
            "Project":    {"type": "STRING", "value": item.get("project", "")},
            "Client":     {"type": "STRING", "value": item.get("client", "")},
            "Topic":      {"type": "STRING", "value": item.get("topic", "")},
            "UploadedBy": {"type": "STRING", "value": item.get("uploaded_by", "")},
            "UploadedAt": {"type": "STRING", "value": item.get("uploaded_at", datetime.now(timezone.utc).isoformat())}
        }
    }

    sidecar_key = f"{s3_key}.metadata.json"

    s3.put_object(
        Bucket=bucket,
        Key=sidecar_key,
        Body=json.dumps(metadata, indent=2),
        ContentType="application/json"
    )

    s3.copy_object(
        Bucket=PROCESSED_BUCKET,
        CopySource={"Bucket": bucket, "Key": s3_key},
        Key=s3_key
    )
    s3.copy_object(
        Bucket=PROCESSED_BUCKET,
        CopySource={"Bucket": bucket, "Key": sidecar_key},
        Key=sidecar_key
    )

    if document_id:
        table.update_item(
            Key={"document_id": document_id},
            UpdateExpression="SET #s = :s, sidecar_key = :sk",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={":s": "SIDECAR_CREATED", ":sk": sidecar_key}
        )

    if BEDROCK_KB_ID and BEDROCK_DS_ID:
        try:
            resp   = bedrock_agent.start_ingestion_job(
                knowledgeBaseId=BEDROCK_KB_ID,
                dataSourceId=BEDROCK_DS_ID
            )
            job_id = resp["ingestionJob"]["ingestionJobId"]
            print(f"Started ingestion job: {job_id}")
            if document_id:
                table.update_item(
                    Key={"document_id": document_id},
                    UpdateExpression="SET #s = :s, ingestion_job_id = :j",
                    ExpressionAttributeNames={"#s": "status"},
                    ExpressionAttributeValues={":s": "INDEXING", ":j": job_id}
                )
        except Exception as e:
            print(f"Failed to start ingestion job (non-fatal): {e}")
    else:
        print("BEDROCK_KB_ID/DS_ID not set — skipping ingestion trigger")
