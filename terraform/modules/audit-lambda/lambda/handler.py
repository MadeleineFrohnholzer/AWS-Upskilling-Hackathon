import json
import logging
import os
import boto3
from datetime import datetime, timezone

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3       = boto3.client("s3")
dynamodb = boto3.client("dynamodb")

PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
AUDIT_TABLE      = os.environ["AUDIT_TABLE"]

METADATA_SUFFIX = ".metadata.json"


def handler(event, _context):
    for record in event.get("Records", []):
        key = record["s3"]["object"]["key"]
        logger.info("Audit event for key=%s", key)
        try:
            _upsert(key)
        except Exception:
            logger.exception("Failed to upsert audit record for key=%s", key)


def _upsert(key):
    now = datetime.now(timezone.utc).isoformat()

    if key.endswith(METADATA_SUFFIX):
        filename = key[: -len(METADATA_SUFFIX)]
        metadata = json.loads(s3.get_object(Bucket=PROCESSED_BUCKET, Key=key)["Body"].read())
        _upsert_with_metadata(filename, metadata, now)
    else:
        filename = os.path.splitext(key)[0]
        _upsert_filename_only(filename, now)


def _upsert_with_metadata(filename, metadata, now):
    update_expr = (
        "SET #updated_at = :now, #created_at = if_not_exists(#created_at, :now), "
        "Industry = :industry, DocumentType = :doc_type"
    )
    expr_names  = {"#updated_at": "updated_at", "#created_at": "created_at"}
    expr_values = {
        ":now":      {"S": now},
        ":industry": {"S": metadata.get("Industry", "")},
        ":doc_type": {"S": metadata.get("DocumentType", "")},
    }
    for field in ("UseCase", "Client", "UploadedBy", "UploadedAt"):
        if field in metadata:
            update_expr += f", {field} = :{field}"
            expr_values[f":{field}"] = {"S": metadata[field]}

    dynamodb.update_item(
        TableName=AUDIT_TABLE,
        Key={"filename": {"S": filename}},
        UpdateExpression=update_expr,
        ExpressionAttributeNames=expr_names,
        ExpressionAttributeValues=expr_values,
    )


def _upsert_filename_only(filename, now):
    dynamodb.update_item(
        TableName=AUDIT_TABLE,
        Key={"filename": {"S": filename}},
        UpdateExpression="SET #updated_at = :now, #created_at = if_not_exists(#created_at, :now)",
        ExpressionAttributeNames={"#updated_at": "updated_at", "#created_at": "created_at"},
        ExpressionAttributeValues={":now": {"S": now}},
    )
