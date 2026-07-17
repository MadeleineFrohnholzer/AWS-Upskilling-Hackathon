"""
VPC Endpoint Verification Lambda

Runs inside the VPC private subnet and verifies that all PrivateLink
endpoints are reachable. Intended to be invoked once after provisioning
to confirm the networking setup before the hackathon starts.

Returns a JSON report of which endpoints are reachable and which failed.
"""

import json
import urllib.request
import urllib.error
import ssl
import socket
import boto3
from botocore.config import Config


def lambda_handler(event, context):
    """Test connectivity to all VPC endpoints from inside the private subnet."""

    region = boto3.session.Session().region_name
    results = {}

    # ─────────────────────────────────────────────────────────────────────
    # 1. STS — verify IAM role assumption works via PrivateLink
    # ─────────────────────────────────────────────────────────────────────
    try:
        sts = boto3.client("sts", config=Config(region_name=region))
        identity = sts.get_caller_identity()
        results["sts"] = {
            "status": "OK",
            "detail": f"Account: {identity['Account']}, Role: {identity['Arn']}"
        }
    except Exception as e:
        results["sts"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 2. S3 — list buckets via Gateway endpoint
    # ─────────────────────────────────────────────────────────────────────
    try:
        s3 = boto3.client("s3", config=Config(region_name=region))
        buckets = s3.list_buckets()
        results["s3"] = {
            "status": "OK",
            "detail": f"Found {len(buckets['Buckets'])} buckets"
        }
    except Exception as e:
        results["s3"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 3. DynamoDB — list tables via Gateway endpoint
    # ─────────────────────────────────────────────────────────────────────
    try:
        ddb = boto3.client("dynamodb", config=Config(region_name=region))
        tables = ddb.list_tables()
        results["dynamodb"] = {
            "status": "OK",
            "detail": f"Found {len(tables['TableNames'])} tables"
        }
    except Exception as e:
        results["dynamodb"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 4. Bedrock Runtime — list foundation models
    # ─────────────────────────────────────────────────────────────────────
    try:
        bedrock = boto3.client("bedrock", config=Config(region_name=region))
        models = bedrock.list_foundation_models(byOutputModality="TEXT")
        results["bedrock_runtime"] = {
            "status": "OK",
            "detail": f"Found {len(models['modelSummaries'])} text models"
        }
    except Exception as e:
        results["bedrock_runtime"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 5. Textract — detect document text (dry run, no input needed)
    # ─────────────────────────────────────────────────────────────────────
    try:
        textract = boto3.client("textract", config=Config(region_name=region))
        # Just verify the endpoint resolves and responds
        # This will throw a validation error (no document), but that proves connectivity
        textract.detect_document_text(Document={"Bytes": b"test"})
        results["textract"] = {"status": "OK", "detail": "Endpoint reachable"}
    except textract.exceptions.InvalidParameterException:
        # This error means we reached Textract — endpoint works!
        results["textract"] = {"status": "OK", "detail": "Endpoint reachable (expected validation error)"}
    except Exception as e:
        if "InvalidParameterException" in str(e) or "UnsupportedDocumentException" in str(e):
            results["textract"] = {"status": "OK", "detail": "Endpoint reachable (expected validation error)"}
        else:
            results["textract"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 6. ECR — verify image registry endpoint
    # ─────────────────────────────────────────────────────────────────────
    try:
        ecr = boto3.client("ecr", config=Config(region_name=region))
        repos = ecr.describe_repositories()
        results["ecr"] = {
            "status": "OK",
            "detail": f"Found {len(repos['repositories'])} repositories"
        }
    except ecr.exceptions.RepositoryNotFoundException:
        results["ecr"] = {"status": "OK", "detail": "Endpoint reachable (no repos yet)"}
    except Exception as e:
        results["ecr"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 7. CloudWatch Logs — verify log endpoint
    # ─────────────────────────────────────────────────────────────────────
    try:
        logs = boto3.client("logs", config=Config(region_name=region))
        log_groups = logs.describe_log_groups(limit=1)
        results["cloudwatch_logs"] = {
            "status": "OK",
            "detail": f"Endpoint reachable, found {len(log_groups['logGroups'])} log groups"
        }
    except Exception as e:
        results["cloudwatch_logs"] = {"status": "FAIL", "detail": str(e)}

    # ─────────────────────────────────────────────────────────────────────
    # 8. DNS resolution check for all interface endpoints
    # ─────────────────────────────────────────────────────────────────────
    dns_checks = {
        "bedrock-runtime": f"bedrock-runtime.{region}.amazonaws.com",
        "bedrock-agent-runtime": f"bedrock-agent-runtime.{region}.amazonaws.com",
        "textract": f"textract.{region}.amazonaws.com",
        "ecr.api": f"api.ecr.{region}.amazonaws.com",
        "ecr.dkr": f"dkr.ecr.{region}.amazonaws.com",
        "logs": f"logs.{region}.amazonaws.com",
        "sts": f"sts.{region}.amazonaws.com",
    }

    dns_results = {}
    for name, hostname in dns_checks.items():
        try:
            ip = socket.gethostbyname(hostname)
            # Private IPs (10.x.x.x) indicate PrivateLink is working
            is_private = ip.startswith("10.") or ip.startswith("172.") or ip.startswith("192.168.")
            dns_results[name] = {
                "status": "OK" if is_private else "WARN",
                "ip": ip,
                "private": is_private
            }
        except socket.gaierror as e:
            dns_results[name] = {"status": "FAIL", "error": str(e)}

    results["dns_resolution"] = dns_results

    # ─────────────────────────────────────────────────────────────────────
    # Summary
    # ─────────────────────────────────────────────────────────────────────
    all_ok = all(
        v.get("status") == "OK"
        for k, v in results.items()
        if k != "dns_resolution"
    )
    dns_ok = all(
        v.get("status") in ("OK", "WARN")
        for v in results.get("dns_resolution", {}).values()
    )

    summary = {
        "all_endpoints_reachable": all_ok and dns_ok,
        "region": region,
        "results": results,
    }

    print(json.dumps(summary, indent=2, default=str))

    return {
        "statusCode": 200 if (all_ok and dns_ok) else 500,
        "body": json.dumps(summary, indent=2, default=str)
    }
