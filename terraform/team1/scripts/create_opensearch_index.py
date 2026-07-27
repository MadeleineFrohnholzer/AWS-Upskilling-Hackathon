"""
Creates the knn vector index in OpenSearch Serverless required by Bedrock Knowledge Base.
Called by null_resource.opensearch_index after the collection becomes ACTIVE.
"""

import boto3
import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

COLLECTION_ENDPOINT = os.environ["COLLECTION_ENDPOINT"]
AWS_REGION          = os.environ.get("AWS_REGION", "eu-central-1")
INDEX_NAME          = os.environ.get("INDEX_NAME", "bedrock-knowledge-base-default-index")

INDEX_BODY = {
    "settings": {
        "index": {
            "knn": True,
            "knn.algo_param.ef_search": 512
        }
    },
    "mappings": {
        "properties": {
            "bedrock-knowledge-base-default-vector": {
                "type":      "knn_vector",
                "dimension": 1024,
                "method": {
                    "name":       "hnsw",
                    "engine":     "faiss",
                    "space_type": "l2"
                }
            },
            "AMAZON_BEDROCK_TEXT_CHUNK": {"type": "text"},
            "AMAZON_BEDROCK_METADATA":   {"type": "text", "index": False}
        }
    }
}


def sign_request(url, method, body, region, service="aoss"):
    """Sign request with SigV4 using boto3 credentials."""
    from botocore.auth import SigV4Auth
    from botocore.awsrequest import AWSRequest
    from botocore.credentials import get_credentials
    import botocore.session

    session     = botocore.session.get_session()
    credentials = session.get_credentials().get_frozen_credentials()

    request = AWSRequest(method=method, url=url,
                         data=json.dumps(body).encode(),
                         headers={"Content-Type": "application/json",
                                  "host": url.split("/")[2]})
    SigV4Auth(credentials, service, region).add_auth(request)
    return dict(request.headers), request.body


def create_index():
    url = f"https://{COLLECTION_ENDPOINT}/{INDEX_NAME}"
    headers, body = sign_request(url, "PUT", INDEX_BODY, AWS_REGION)

    req = urllib.request.Request(url, data=body, headers=headers, method="PUT")
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            print(f"Index created: {resp.status} {json.loads(resp.read())}")
    except urllib.error.HTTPError as e:
        content = e.read().decode()
        if "resource_already_exists_exception" in content.lower():
            print("Index already exists — skipping.")
        else:
            print(f"Failed to create index: {e.code} {content}", file=sys.stderr)
            sys.exit(1)


if __name__ == "__main__":
    create_index()
