import json
import logging
import boto3
import os

logger = logging.getLogger()
logger.setLevel(logging.INFO)

s3 = boto3.client("s3")

LANDING_BUCKET   = os.environ["LANDING_BUCKET"]
PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]


def handler(event, _context):
    logger.info("Ingest triggered with %d record(s)", len(event.get("Records", [])))

    for record in event.get("Records", []):
        key = record["s3"]["object"]["key"]

        if key.endswith(".metadata.json"):
            logger.info("Skipping metadata sidecar event for key=%s", key)
            continue

        logger.info("Processing document key=%s", key)
        try:
            _move_document(key)
        except Exception:
            logger.exception("Failed to process document key=%s, skipping", key)

    return {"statusCode": 200}


def _move_document(key):
    metadata_key = f"{os.path.splitext(key)[0]}.metadata.json"

    try:
        s3.head_object(Bucket=LANDING_BUCKET, Key=metadata_key)
    except s3.exceptions.ClientError as e:
        if e.response["Error"]["Code"] == "404":
            logger.error("Metadata sidecar missing: bucket=%s key=%s", LANDING_BUCKET, metadata_key)
            return
        raise

    for src_key in (key, metadata_key):
        logger.info("Copying key=%s to bucket=%s", src_key, PROCESSED_BUCKET)
        s3.copy_object(
            CopySource={"Bucket": LANDING_BUCKET, "Key": src_key},
            Bucket=PROCESSED_BUCKET,
            Key=src_key,
        )
        logger.info("Copied key=%s successfully", src_key)

    logger.info("Deleting originals from landing bucket")
    for src_key in (key, metadata_key):
        s3.delete_object(Bucket=LANDING_BUCKET, Key=src_key)
        logger.info("Deleted key=%s from landing bucket", src_key)

    logger.info("Move complete for document key=%s", key)
