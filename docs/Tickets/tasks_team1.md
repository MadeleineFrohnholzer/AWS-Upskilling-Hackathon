# M0 — Foundation & Ingestion: Detailed Ticket Specifications

> **Milestone owner:** Team 0 (Aigul, Sandro)
> **Definition of done:** A document can be uploaded, tagged, vectorized, and retrieved with metadata filters.
> **State file:** `team0/terraform.tfstate` — backend bucket `hackathon-tf-state-064453091991`, region `eu-central-1`
> **Critical outputs for Team 1:** `bedrock_kb_id`, `bedrock_kb_arn`, `s3_vector_store_arn`, `landing_bucket_name`

---

## What's Already Done (Storage Module — Day 1 Complete)

The `modules/storage` module already provisions:

| Resource | Name pattern | Status |
|----------|-------------|--------|
| S3 landing bucket | `knowledge-base-landing-<random>` | Done — KMS encrypted, versioned, public-access blocked |
| S3 processed bucket | `knowledge-base-processed-<random>` | Done — KMS encrypted, versioned, public-access blocked |
| DynamoDB sessions table | `knowledge-base-sessions` | Done — PAY_PER_REQUEST, TTL on `expires_at` |
| DynamoDB feedback table | `knowledge-base-feedback` | Done — hash: `feedback_id`, range: `timestamp` |

**Remaining work is organized into five tickets below.**

---

## TICKET M0-01 — DynamoDB Documents Table + S3 Bucket Policy

### Goal

Add a **documents catalog table** in DynamoDB to track upload state and metadata for every file. Also attach bucket policies so Bedrock Knowledge Base can read from the processed bucket (required for M0-04).

### Why a Separate Document Table

The existing `sessions` and `feedback` tables serve different purposes. We need a queryable index of every uploaded document so the digest Lambda (M0-05) can report statistics per Industry/Type, and so the sidecar Lambda (M0-03) can look up metadata by document ID.

### Terraform Resources

Add to `terraform/modules/storage/main.tf` (or directly to `terraform/team0/main.tf`):

```hcl
# -------------------------------------------------------
# DynamoDB: Document Catalog
# Tracks every upload: state, metadata, S3 location
# -------------------------------------------------------
resource "aws_dynamodb_table" "documents" {
  name         = "${var.project_name}-documents"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "document_id"

  attribute {
    name = "document_id"
    type = "S"
  }

  # GSI: query documents by Industry
  attribute {
    name = "industry"
    type = "S"
  }

  # GSI: query documents by upload timestamp
  attribute {
    name = "uploaded_at"
    type = "S"
  }

  global_secondary_index {
    name            = "industry-uploaded_at-index"
    hash_key        = "industry"
    range_key       = "uploaded_at"
    projection_type = "ALL"
  }

  ttl {
    attribute_name = "expires_at"
    enabled        = true
  }

  tags = {
    Name        = "${var.project_name}-documents"
    Environment = var.environment
  }
}
```

DynamoDB item schema (for reference — enforced by Lambda, not DynamoDB):

```json
{
  "document_id":  "uuid-v4",
  "filename":     "accenture-banking-poc-2025.pdf",
  "s3_key":       "uploads/uuid-v4/accenture-banking-poc-2025.pdf",
  "industry":     "Banking",
  "type":         "PoC",
  "project":      "Titan",
  "client":       "",
  "topic":        "Engineering",
  "uploaded_by":  "zoltan.szilagyi@accenture.com",
  "uploaded_at":  "2026-07-28T09:00:00Z",
  "status":       "UPLOADED | SIDECAR_CREATED | INDEXED | FAILED",
  "sidecar_key":  "uploads/uuid-v4/accenture-banking-poc-2025.pdf.metadata.json"
}
```

S3 bucket policy for Bedrock KB access (add to `terraform/team0/main.tf`):

```hcl
# Allow Bedrock Knowledge Base service to read the processed bucket
data "aws_iam_policy_document" "bedrock_kb_s3" {
  statement {
    sid     = "BedrockKBRead"
    effect  = "Allow"
    principals {
      type        = "Service"
      identifiers = ["bedrock.amazonaws.com"]
    }
    actions   = ["s3:GetObject", "s3:ListBucket"]
    resources = [
      module.storage.processed_bucket_arn,
      "${module.storage.processed_bucket_arn}/*"
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.current.account_id]
    }
  }
}

resource "aws_s3_bucket_policy" "processed_bedrock" {
  bucket = module.storage.processed_bucket_id
  policy = data.aws_iam_policy_document.bedrock_kb_s3.json
}

data "aws_caller_identity" "current" {}
```

Add outputs to `terraform/team0/outputs.tf`:

```hcl
output "documents_table_name" {
  description = "DynamoDB documents catalog table name"
  value       = aws_dynamodb_table.documents.name
}

output "documents_table_arn" {
  description = "DynamoDB documents catalog table ARN"
  value       = aws_dynamodb_table.documents.arn
}
```

### Acceptance Criteria

- [x] `terraform apply` creates the `knowledge-base-documents` table
- [x] GSI `industry-uploaded_at-index` exists and is ACTIVE
- [ ] `aws dynamodb describe-table --table-name knowledge-base-documents` returns `TableStatus: ACTIVE`
- [x] S3 bucket policy on the processed bucket is applied — Bedrock service principal can read it
- [ ] A manual `aws dynamodb put-item` with a test document record succeeds
- [ ] Query by GSI: `aws dynamodb query --table-name knowledge-base-documents --index-name industry-uploaded_at-index --key-condition-expression "industry = :i" --expression-attribute-values '{":i":{"S":"Banking"}}'` returns results

### Effort Estimate

**Day 1 afternoon** — 30 minutes alongside S3/DynamoDB module

---

## TICKET M0-02 — API Gateway + Lambda Presigned URL Generator

### Goal

Expose a REST API (VPC-only, no public endpoint) with a `POST /upload-url` endpoint. The Lambda generates an S3 presigned PUT URL valid for 15 minutes, records the document metadata in DynamoDB, and returns everything the caller needs to upload a file directly to S3.

### API Contract

```
POST /upload-url
Content-Type: application/json

{
  "filename":    "accenture-banking-poc-2025.pdf",
  "industry":    "Banking",
  "type":        "PoC",
  "project":     "Titan",
  "topic":       "Engineering",
  "client":      "",
  "uploaded_by": "zoltan.szilagyi@accenture.com"
}

→ 200 OK
{
  "document_id": "a3f2c1d0-...",
  "upload_url":  "https://s3.eu-central-1.amazonaws.com/knowledge-base-landing-.../uploads/a3f2c1d0-.../accenture-banking-poc-2025.pdf?X-Amz-...",
  "s3_key":      "uploads/a3f2c1d0-.../accenture-banking-poc-2025.pdf",
  "expires_in":  900
}
```

### Lambda Implementation

Create `terraform/team0/lambda/presigned_url/index.py`:

```python
import boto3
import json
import os
import uuid
from datetime import datetime, timezone

s3 = boto3.client("s3")
dynamodb = boto3.resource("dynamodb")

LANDING_BUCKET   = os.environ["LANDING_BUCKET"]
DOCUMENTS_TABLE  = os.environ["DOCUMENTS_TABLE"]
PRESIGN_EXPIRY   = 900  # 15 minutes

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

    document_id  = str(uuid.uuid4())
    s3_key       = f"uploads/{document_id}/{filename}"
    uploaded_at  = datetime.now(timezone.utc).isoformat()

    # Write metadata to DynamoDB before generating the URL
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

    # Generate presigned PUT URL
    upload_url = s3.generate_presigned_url(
        "put_object",
        Params={
            "Bucket": LANDING_BUCKET,
            "Key":    s3_key,
            "ContentType": "application/octet-stream"
        },
        ExpiresIn=PRESIGN_EXPIRY
    )

    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({
            "document_id": document_id,
            "upload_url":  upload_url,
            "s3_key":      s3_key,
            "expires_in":  PRESIGN_EXPIRY
        })
    }

def _error(code, message):
    return {
        "statusCode": code,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"error": message})
    }
```

### Terraform Resources

Add to `terraform/team0/main.tf`:

```hcl
# -------------------------------------------------------
# IAM Role for presigned URL Lambda
# -------------------------------------------------------
resource "aws_iam_role" "presign_lambda" {
  name = "${var.project_name}-presign-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "presign_lambda" {
  name = "presign-permissions"
  role = aws_iam_role.presign_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = "${module.storage.landing_bucket_arn}/uploads/*"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:UpdateItem"]
        Resource = aws_dynamodb_table.documents.arn
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "presign_vpc" {
  role       = aws_iam_role.presign_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# -------------------------------------------------------
# Lambda: presigned URL generator
# -------------------------------------------------------
data "archive_file" "presign_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/presigned_url"
  output_path = "${path.module}/lambda/presigned_url.zip"
}

resource "aws_lambda_function" "presign" {
  function_name    = "${var.project_name}-presign-url"
  role             = aws_iam_role.presign_lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  timeout          = 10
  memory_size      = 128
  filename         = data.archive_file.presign_lambda.output_path
  source_code_hash = data.archive_file.presign_lambda.output_base64sha256

  environment {
    variables = {
      LANDING_BUCKET  = module.storage.landing_bucket_id
      DOCUMENTS_TABLE = aws_dynamodb_table.documents.name
    }
  }

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_security_group_id]
  }
}

resource "aws_cloudwatch_log_group" "presign_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.presign.function_name}"
  retention_in_days = 7
}

# -------------------------------------------------------
# API Gateway (REST, private — VPC endpoint only)
# -------------------------------------------------------
resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.project_name}-api"
  description = "Internal document ingestion API"

  endpoint_configuration {
    types            = ["PRIVATE"]
    vpc_endpoint_ids = [data.terraform_remote_state.shared.outputs.endpoint_ids["execute-api"]]
  }
}

# Resource: /upload-url
resource "aws_api_gateway_resource" "upload_url" {
  rest_api_id = aws_api_gateway_rest_api.main.id
  parent_id   = aws_api_gateway_rest_api.main.root_resource_id
  path_part   = "upload-url"
}

resource "aws_api_gateway_method" "upload_url_post" {
  rest_api_id   = aws_api_gateway_rest_api.main.id
  resource_id   = aws_api_gateway_resource.upload_url.id
  http_method   = "POST"
  authorization = "NONE"    # VPN enforces access; add Cognito authorizer as stretch goal
}

resource "aws_api_gateway_integration" "upload_url_post" {
  rest_api_id             = aws_api_gateway_rest_api.main.id
  resource_id             = aws_api_gateway_resource.upload_url.id
  http_method             = aws_api_gateway_method.upload_url_post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.presign.invoke_arn
}

resource "aws_lambda_permission" "api_gw_presign" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.presign.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.main.execution_arn}/*/*"
}

resource "aws_api_gateway_deployment" "main" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.upload_url.id,
      aws_api_gateway_method.upload_url_post.id,
      aws_api_gateway_integration.upload_url_post.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "main" {
  deployment_id = aws_api_gateway_deployment.main.id
  rest_api_id   = aws_api_gateway_rest_api.main.id
  stage_name    = var.environment
}

# Resource policy: allow calls only from within the VPC
resource "aws_api_gateway_rest_api_policy" "vpce_only" {
  rest_api_id = aws_api_gateway_rest_api.main.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = "*"
      Action    = "execute-api:Invoke"
      Resource  = "${aws_api_gateway_rest_api.main.execution_arn}/*"
      Condition = {
        StringEquals = {
          "aws:SourceVpc" = local.vpc_id
        }
      }
    }]
  })
}
```

Add outputs:

```hcl
output "api_endpoint" {
  description = "Internal API Gateway base URL"
  value       = "https://${aws_api_gateway_rest_api.main.id}.execute-api.${var.region}.amazonaws.com/${var.environment}"
}
```

### Acceptance Criteria

- [x] `terraform apply` creates the Lambda, API Gateway, and IAM role
- [ ] `aws lambda invoke --function-name knowledge-base-presign-url --payload '{"body":"{\"filename\":\"test.pdf\",\"industry\":\"Banking\",\"type\":\"PoC\"}"}' /tmp/out.json` returns `statusCode: 200`
- [ ] The presigned URL in the response accepts a `curl -T test.pdf "<url>"` PUT request and the file appears in S3
- [ ] DynamoDB shows a new item with `status: PENDING_UPLOAD` after calling the API
- [ ] Calling with `"industry": "FakeIndustry"` returns `statusCode: 400`
- [x] API Gateway endpoint is not reachable from outside the VPC (returns connection refused or timeout from public internet)
- [ ] CloudWatch log group `/aws/lambda/knowledge-base-presign-url` receives logs on each invocation

### Effort Estimate

**Day 2 morning** — Lambda + IAM (~1.5h), API Gateway (~1h)

### Key Pitfalls

- Private API Gateway requires a VPC endpoint for `execute-api` — this is pre-provisioned in shared infra; reference it via `data.terraform_remote_state.shared.outputs.endpoint_ids["execute-api"]`
- The API Gateway resource policy (`aws_api_gateway_rest_api_policy`) is a **separate resource** from the API — without it, private APIs reject all calls
- Always use `create_before_destroy = true` on the deployment to avoid downtime during redeployment
- The presigned URL is generated with `s3:PutObject`, not `s3:GetObject` — the Lambda role only needs put permission on the landing bucket

---

## TICKET M0-03 — Lambda Metadata Sidecar + S3 Event Trigger

### Goal

When a file lands in the S3 landing bucket, automatically: create a `.metadata.json` sidecar (matching the shared schema), copy both files to the processed bucket, update the DynamoDB document status, and kick off a Bedrock Knowledge Base sync job.

### S3 Key Convention

```
uploads/<document_id>/<filename>                    ← original upload
uploads/<document_id>/<filename>.metadata.json      ← sidecar (created by this Lambda)
```

The Bedrock KB data source is configured to read `*.metadata.json` files as metadata sidecars alongside their companion documents.

### Lambda Implementation

Create `terraform/team0/lambda/sidecar/index.py`:

```python
import boto3
import json
import os
import urllib.parse
from datetime import datetime, timezone

s3          = boto3.client("s3")
dynamodb    = boto3.resource("dynamodb")
bedrock_agent = boto3.client("bedrock-agent")

PROCESSED_BUCKET = os.environ["PROCESSED_BUCKET"]
DOCUMENTS_TABLE  = os.environ["DOCUMENTS_TABLE"]
BEDROCK_KB_ID    = os.environ["BEDROCK_KB_ID"]       # filled after M0-04
BEDROCK_DS_ID    = os.environ["BEDROCK_DS_ID"]       # filled after M0-04

def handler(event, context):
    for record in event["Records"]:
        bucket   = record["s3"]["bucket"]["name"]
        raw_key  = record["s3"]["object"]["key"]
        s3_key   = urllib.parse.unquote_plus(raw_key)

        # Skip sidecar files to avoid infinite trigger loop
        if s3_key.endswith(".metadata.json"):
            print(f"Skipping sidecar: {s3_key}")
            continue

        print(f"Processing: s3://{bucket}/{s3_key}")
        _process(bucket, s3_key)

def _process(bucket, s3_key):
    table = dynamodb.Table(DOCUMENTS_TABLE)

    # Extract document_id from key: uploads/<document_id>/<filename>
    parts       = s3_key.split("/")
    document_id = parts[1] if len(parts) >= 3 else None

    # Fetch metadata from DynamoDB
    if document_id:
        item = table.get_item(Key={"document_id": document_id}).get("Item", {})
    else:
        item = {}

    # Build sidecar (Bedrock KB metadata format)
    metadata = {
        "metadataAttributes": {
            "Industry":   item.get("industry", "Other"),
            "Type":       item.get("type", "Other"),
            "Project":    item.get("project", ""),
            "Client":     item.get("client", ""),
            "Topic":      item.get("topic", ""),
            "UploadedBy": item.get("uploaded_by", ""),
            "UploadedAt": item.get("uploaded_at", datetime.now(timezone.utc).isoformat())
        }
    }

    sidecar_key = f"{s3_key}.metadata.json"

    # Write sidecar to landing bucket (Bedrock KB syncs from landing or processed — configure one)
    s3.put_object(
        Bucket=bucket,
        Key=sidecar_key,
        Body=json.dumps(metadata, indent=2),
        ContentType="application/json"
    )

    # Copy original + sidecar to processed bucket
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

    # Update DynamoDB status
    if document_id:
        table.update_item(
            Key={"document_id": document_id},
            UpdateExpression="SET #s = :s, sidecar_key = :sk",
            ExpressionAttributeNames={"#s": "status"},
            ExpressionAttributeValues={
                ":s": "SIDECAR_CREATED",
                ":sk": sidecar_key
            }
        )

    # Trigger Bedrock KB sync (StartIngestionJob)
    if BEDROCK_KB_ID and BEDROCK_DS_ID:
        try:
            response = bedrock_agent.start_ingestion_job(
                knowledgeBaseId=BEDROCK_KB_ID,
                dataSourceId=BEDROCK_DS_ID
            )
            job_id = response["ingestionJob"]["ingestionJobId"]
            print(f"Started ingestion job: {job_id}")

            if document_id:
                table.update_item(
                    Key={"document_id": document_id},
                    UpdateExpression="SET #s = :s, ingestion_job_id = :j",
                    ExpressionAttributeNames={"#s": "status"},
                    ExpressionAttributeValues={":s": "INDEXING", ":j": job_id}
                )
        except Exception as e:
            print(f"Failed to start ingestion job: {e}")
            # Non-fatal — KB can be synced manually if needed
    else:
        print("BEDROCK_KB_ID/DS_ID not set — skipping ingestion trigger")
```

### Terraform Resources

```hcl
# -------------------------------------------------------
# IAM Role for sidecar Lambda
# -------------------------------------------------------
resource "aws_iam_role" "sidecar_lambda" {
  name = "${var.project_name}-sidecar-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "sidecar_lambda" {
  name = "sidecar-permissions"
  role = aws_iam_role.sidecar_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:PutObject"]
        Resource = ["${module.storage.landing_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["s3:PutObject"]
        Resource = ["${module.storage.processed_bucket_arn}/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:GetItem", "dynamodb:UpdateItem"]
        Resource = [aws_dynamodb_table.documents.arn]
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:StartIngestionJob"]
        Resource = "*"    # narrow to KB ARN after M0-04
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "sidecar_vpc" {
  role       = aws_iam_role.sidecar_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# -------------------------------------------------------
# Lambda: metadata sidecar creator
# -------------------------------------------------------
data "archive_file" "sidecar_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/sidecar"
  output_path = "${path.module}/lambda/sidecar.zip"
}

resource "aws_lambda_function" "sidecar" {
  function_name    = "${var.project_name}-metadata-sidecar"
  role             = aws_iam_role.sidecar_lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.sidecar_lambda.output_path
  source_code_hash = data.archive_file.sidecar_lambda.output_base64sha256

  environment {
    variables = {
      PROCESSED_BUCKET = module.storage.processed_bucket_id
      DOCUMENTS_TABLE  = aws_dynamodb_table.documents.name
      BEDROCK_KB_ID    = ""    # fill in after M0-04; update via terraform apply
      BEDROCK_DS_ID    = ""    # fill in after M0-04
    }
  }

  vpc_config {
    subnet_ids         = local.private_subnet_ids
    security_group_ids = [local.lambda_security_group_id]
  }
}

resource "aws_cloudwatch_log_group" "sidecar_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.sidecar.function_name}"
  retention_in_days = 7
}

# -------------------------------------------------------
# S3 Event Notification → sidecar Lambda
# -------------------------------------------------------
resource "aws_lambda_permission" "s3_sidecar" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.sidecar.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = module.storage.landing_bucket_arn
}

resource "aws_s3_bucket_notification" "landing_trigger" {
  bucket = module.storage.landing_bucket_id

  lambda_function {
    lambda_function_arn = aws_lambda_function.sidecar.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "uploads/"
    filter_suffix       = ""    # all file types; sidecar Lambda skips *.metadata.json
  }

  depends_on = [aws_lambda_permission.s3_sidecar]
}
```

### Acceptance Criteria

- [ ] Upload a test PDF via the presigned URL; within 30 seconds a `.metadata.json` sidecar appears alongside it in the landing bucket
- [ ] Both the original file and sidecar are copied to the processed bucket
- [ ] DynamoDB item transitions: `PENDING_UPLOAD → SIDECAR_CREATED → INDEXING`
- [ ] CloudWatch logs for the sidecar Lambda show no errors
- [ ] Uploading a file directly (bypassing the presigned-URL API) still triggers the Lambda; sidecar is created with default `Other`/`Other` values (graceful degradation)
- [x] Uploading a `.metadata.json` file directly does NOT trigger infinite recursion (Lambda skips sidecar files)
- [ ] Once M0-04 is deployed, a Bedrock ingestion job starts automatically after each upload

### Effort Estimate

**Day 2 afternoon** — Lambda code + S3 notification (~2h)
**Day 3 morning** — wire `BEDROCK_KB_ID` after KB is created, end-to-end test

### Key Pitfalls

- The `aws_lambda_permission` with `principal = "s3.amazonaws.com"` must be applied **before** `aws_s3_bucket_notification`, or S3 cannot invoke the Lambda
- Filter `filter_suffix = ""` means all object types trigger the notification; the Lambda must explicitly skip `.metadata.json` keys to avoid an infinite loop
- The sidecar `metadataAttributes` key names must exactly match the schema in `docs/metadata-schema.md` — `Industry`, `Type`, etc. are case-sensitive; Bedrock KB rejects unknown keys silently

---

## TICKET M0-04 — Bedrock Knowledge Base + Titan V2 Embeddings

### Goal

Create a Bedrock Knowledge Base backed by an S3 Vector Store. Configure Titan Text Embeddings V2 as the embedding model and the processed S3 bucket as the data source. This is the critical integration point: the `bedrock_kb_id` output is what Team 1 plugs into their agent.

### Pre-Step: Enable Model Access

Bedrock models require explicit opt-in:

1. Open AWS Console → Amazon Bedrock → Model access (eu-central-1)
2. Enable: **Amazon Titan Text Embeddings V2** + **Anthropic Claude 3.5 Sonnet**
3. Wait for status to become **Access granted** (usually instant for Titan)

```bash
# Verify via CLI
aws bedrock list-foundation-models --region eu-central-1 \
  --query "modelSummaries[?modelId=='amazon.titan-embed-text-v2:0'].{id:modelId,status:modelLifecycle.status}"
```

### S3 Vector Store

Bedrock S3 Vector Store requires a **dedicated bucket** separate from documents:

```hcl
# -------------------------------------------------------
# S3 Vector Store Bucket (for embeddings)
# -------------------------------------------------------
resource "aws_s3_bucket" "vector_store" {
  bucket_prefix = "${var.project_name}-vectors-"

  tags = {
    Name        = "${var.project_name}-vectors"
    Environment = var.environment
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "vector_store" {
  bucket = aws_s3_bucket.vector_store.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "vector_store" {
  bucket                  = aws_s3_bucket.vector_store.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Bedrock needs read/write on the vector store bucket
resource "aws_s3_bucket_policy" "vector_store_bedrock" {
  bucket = aws_s3_bucket.vector_store.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
      Resource  = [
        aws_s3_bucket.vector_store.arn,
        "${aws_s3_bucket.vector_store.arn}/*"
      ]
      Condition = {
        StringEquals = { "aws:SourceAccount" = data.aws_caller_identity.current.account_id }
      }
    }]
  })
}
```

### Terraform Resources — Knowledge Base

```hcl
# -------------------------------------------------------
# IAM Role for Bedrock Knowledge Base
# -------------------------------------------------------
resource "aws_iam_role" "bedrock_kb" {
  name = "${var.project_name}-bedrock-kb-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "bedrock.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "bedrock_kb" {
  name = "kb-permissions"
  role = aws_iam_role.bedrock_kb.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["bedrock:InvokeModel"]
        Resource = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          module.storage.processed_bucket_arn,
          "${module.storage.processed_bucket_arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject", "s3:ListBucket"]
        Resource = [
          aws_s3_bucket.vector_store.arn,
          "${aws_s3_bucket.vector_store.arn}/*"
        ]
      }
    ]
  })
}

# -------------------------------------------------------
# Bedrock Knowledge Base (S3 Vector Store)
# -------------------------------------------------------
resource "aws_bedrockagent_knowledge_base" "main" {
  name     = "${var.project_name}-knowledge-base"
  role_arn = aws_iam_role.bedrock_kb.arn

  knowledge_base_configuration {
    type = "VECTOR"
    vector_knowledge_base_configuration {
      embedding_model_arn = "arn:aws:bedrock:${var.region}::foundation-model/amazon.titan-embed-text-v2:0"
    }
  }

  storage_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn = aws_s3_bucket.vector_store.arn
    }
  }

  tags = { Name = "${var.project_name}-knowledge-base" }
}

# -------------------------------------------------------
# Data Source: processed S3 bucket
# -------------------------------------------------------
resource "aws_bedrockagent_data_source" "processed" {
  name             = "${var.project_name}-docs-source"
  knowledge_base_id = aws_bedrockagent_knowledge_base.main.id

  data_source_configuration {
    type = "S3"
    s3_configuration {
      bucket_arn          = module.storage.processed_bucket_arn
      inclusion_prefixes  = ["uploads/"]
    }
  }

  # Read .metadata.json sidecars as document metadata
  vector_ingestion_configuration {
    chunking_configuration {
      chunking_strategy = "FIXED_SIZE"
      fixed_size_chunking_configuration {
        max_tokens         = 512
        overlap_percentage = 20
      }
    }

    # Tell Bedrock to look for <filename>.metadata.json alongside each file
    custom_transformation_configuration {
      # Inline metadata — Bedrock KB reads sidecar automatically if bucket_owner_full_control is set
      # No additional config needed when sidecars follow the <key>.metadata.json convention
    }
  }
}
```

### Wiring Back to M0-03

After `terraform apply` succeeds for M0-04, update the sidecar Lambda environment variables:

```hcl
# In aws_lambda_function.sidecar environment block:
BEDROCK_KB_ID = aws_bedrockagent_knowledge_base.main.id
BEDROCK_DS_ID = aws_bedrockagent_data_source.processed.data_source_id
```

### Critical Outputs (consumed by Team 1)

```hcl
output "bedrock_kb_id" {
  description = "Bedrock Knowledge Base ID — Team 1 plugs this into their Agent"
  value       = aws_bedrockagent_knowledge_base.main.id
}

output "bedrock_kb_arn" {
  description = "Bedrock Knowledge Base ARN"
  value       = aws_bedrockagent_knowledge_base.main.arn
}

output "s3_vector_store_arn" {
  description = "S3 Vector Store bucket ARN"
  value       = aws_s3_bucket.vector_store.arn
}

output "landing_bucket_name" {
  description = "Landing bucket name (for presigned URL generation and Team 1 citation links)"
  value       = module.storage.landing_bucket_id
}

output "bedrock_data_source_id" {
  description = "Bedrock KB data source ID (for manual sync trigger)"
  value       = aws_bedrockagent_data_source.processed.data_source_id
}
```

### Acceptance Criteria

- [x] `terraform apply` creates KB, data source, vector store bucket, and all IAM roles
- [ ] `aws bedrock-agent get-knowledge-base --knowledge-base-id <id>` shows `status: ACTIVE`
- [ ] Upload a test PDF through the presigned URL flow → sidecar is created → ingestion job starts
- [ ] `aws bedrock-agent get-ingestion-job --knowledge-base-id <id> --data-source-id <ds> --ingestion-job-id <job>` shows `status: COMPLETE`
- [ ] Test retrieval: `aws bedrock-agent-runtime retrieve --knowledge-base-id <id> --retrieval-query '{"text":"test query"}' --retrieval-configuration '{"vectorSearchConfiguration":{"numberOfResults":3}}'` returns results
- [ ] Metadata-filtered retrieval works: add `filter: {"equals":{"key":"Industry","value":"Banking"}}` to the retrieve call — only Banking documents come back
- [x] `bedrock_kb_id` output is visible in Terraform state and can be read by Team 1 via `terraform_remote_state`

### Effort Estimate

**Day 2 afternoon** — KB + data source Terraform (~1.5h)
**Day 3 morning** — ingest 3–5 test docs, verify metadata filtering works

### Key Pitfalls

- Bedrock KB creation can take 2–3 minutes — `terraform apply` will wait; don't cancel it
- The IAM role for the KB must use a trust policy with `aws:SourceAccount` condition, or Bedrock will reject it
- `inclusion_prefixes` must match the S3 key prefix where documents are stored — if empty, Bedrock scans the entire bucket including sidecars
- Sidecar format for Bedrock: the file must be at `<document_key>.metadata.json` and contain `{"metadataAttributes": {...}}` — not a flat JSON; wrong structure causes silent metadata loss
- `FIXED_SIZE` chunking with 512 tokens / 20% overlap is a sensible default for PDF slides and reports; reduce to 256 tokens for dense technical docs
- S3 Vectors is a newer feature — ensure the account has it enabled in `eu-central-1` before plan/apply

---

## TICKET M0-05 — EventBridge + SES Weekly Digest + CloudWatch

### Goal

Send an automated weekly email digest to the team listing how many documents were indexed per Industry and Type, and alert on Lambda errors and API latency breaches. All triggered by EventBridge; no manual intervention needed.

### Weekly Digest Email Format

```
Subject: [AABG Knowledge Base] Weekly Digest — 2026-07-28

Documents indexed this week: 12

By Industry:
  Banking:     5
  Healthcare:  3
  Automotive:  4

By Type:
  PoC:         6
  Case Study:  4
  Proposal:    2

Recent uploads (last 7 days):
  - accenture-banking-poc-2025.pdf  (Banking / PoC, uploaded by z.szilagyi)
  - titan-architecture-v3.pptx      (Technology / Architecture, uploaded by aigul)
  ...

Knowledge Base status:
  Total documents indexed: 47
  Last sync: 2026-07-27 14:30 UTC
  Vector store size: 47 vectors

---
Sent automatically by the AABG Knowledge Platform.
```

### Lambda Implementation

Create `terraform/team0/lambda/digest/index.py`:

```python
import boto3
import json
import os
from datetime import datetime, timezone, timedelta
from collections import defaultdict

dynamodb = boto3.resource("dynamodb")
ses      = boto3.client("ses", region_name=os.environ["AWS_REGION"])
bedrock_agent = boto3.client("bedrock-agent")

DOCUMENTS_TABLE  = os.environ["DOCUMENTS_TABLE"]
DIGEST_RECIPIENT = os.environ["DIGEST_RECIPIENT"]
DIGEST_SENDER    = os.environ["DIGEST_SENDER"]
BEDROCK_KB_ID    = os.environ["BEDROCK_KB_ID"]

def handler(event, context):
    table     = dynamodb.Table(DOCUMENTS_TABLE)
    one_week_ago = (datetime.now(timezone.utc) - timedelta(days=7)).isoformat()

    # Full scan for aggregate stats (small table — fine for hackathon)
    response = table.scan(
        FilterExpression="attribute_exists(document_id)"
    )
    all_docs = response.get("Items", [])

    recent_docs = [d for d in all_docs if d.get("uploaded_at", "") >= one_week_ago]

    by_industry = defaultdict(int)
    by_type     = defaultdict(int)
    for doc in all_docs:
        by_industry[doc.get("industry", "Other")] += 1
        by_type[doc.get("type", "Other")]         += 1

    # Get KB stats
    try:
        kb_info = bedrock_agent.get_knowledge_base(knowledgeBaseId=BEDROCK_KB_ID)
        kb_status = kb_info["knowledgeBase"]["status"]
    except Exception:
        kb_status = "UNKNOWN"

    body = _build_email(
        recent_docs=recent_docs,
        by_industry=by_industry,
        by_type=by_type,
        total=len(all_docs),
        kb_status=kb_status
    )

    ses.send_email(
        Source=DIGEST_SENDER,
        Destination={"ToAddresses": [DIGEST_RECIPIENT]},
        Message={
            "Subject": {"Data": f"[AABG Knowledge Base] Weekly Digest — {datetime.now(timezone.utc).strftime('%Y-%m-%d')}"},
            "Body":    {"Text": {"Data": body}}
        }
    )
    print(f"Digest sent to {DIGEST_RECIPIENT}")

def _build_email(recent_docs, by_industry, by_type, total, kb_status):
    lines = [
        f"Documents indexed this week: {len(recent_docs)}",
        "",
        "By Industry:"
    ]
    for industry, count in sorted(by_industry.items(), key=lambda x: -x[1]):
        lines.append(f"  {industry:<16} {count}")
    lines += ["", "By Type:"]
    for t, count in sorted(by_type.items(), key=lambda x: -x[1]):
        lines.append(f"  {t:<16} {count}")
    lines += ["", f"Recent uploads (last 7 days):"]
    for doc in sorted(recent_docs, key=lambda d: d.get("uploaded_at",""), reverse=True)[:10]:
        lines.append(f"  - {doc['filename']}  ({doc.get('industry','?')} / {doc.get('type','?')}, "
                     f"uploaded by {doc.get('uploaded_by','unknown')})")
    lines += [
        "",
        "Knowledge Base status:",
        f"  Total documents indexed: {total}",
        f"  KB status: {kb_status}",
        "",
        "---",
        "Sent automatically by the AABG Knowledge Platform."
    ]
    return "\n".join(lines)
```

### Terraform Resources

```hcl
# -------------------------------------------------------
# SES Email Identity (verify sender address)
# -------------------------------------------------------
resource "aws_ses_email_identity" "digest_sender" {
  email = var.digest_sender_email    # e.g. zoltan.szilagyi@accenture.com
}

# -------------------------------------------------------
# IAM Role for digest Lambda
# -------------------------------------------------------
resource "aws_iam_role" "digest_lambda" {
  name = "${var.project_name}-digest-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "digest_lambda" {
  name = "digest-permissions"
  role = aws_iam_role.digest_lambda.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["dynamodb:Scan", "dynamodb:Query"]
        Resource = [aws_dynamodb_table.documents.arn, "${aws_dynamodb_table.documents.arn}/index/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["ses:SendEmail"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["bedrock:GetKnowledgeBase"]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = ["logs:CreateLogGroup", "logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "arn:aws:logs:*:*:*"
      }
    ]
  })
}

data "archive_file" "digest_lambda" {
  type        = "zip"
  source_dir  = "${path.module}/lambda/digest"
  output_path = "${path.module}/lambda/digest.zip"
}

resource "aws_lambda_function" "digest" {
  function_name    = "${var.project_name}-weekly-digest"
  role             = aws_iam_role.digest_lambda.arn
  runtime          = "python3.12"
  handler          = "index.handler"
  timeout          = 60
  memory_size      = 256
  filename         = data.archive_file.digest_lambda.output_path
  source_code_hash = data.archive_file.digest_lambda.output_base64sha256

  environment {
    variables = {
      DOCUMENTS_TABLE  = aws_dynamodb_table.documents.name
      DIGEST_RECIPIENT = var.digest_recipient_email
      DIGEST_SENDER    = var.digest_sender_email
      BEDROCK_KB_ID    = ""    # fill after M0-04
    }
  }
  # Digest Lambda queries DynamoDB via VPC Gateway Endpoint — no VPC config needed
  # unless SES is not accessible from inside VPC (use NAT GW or VPC endpoint for SES)
}

resource "aws_cloudwatch_log_group" "digest_lambda" {
  name              = "/aws/lambda/${aws_lambda_function.digest.function_name}"
  retention_in_days = 14
}

# -------------------------------------------------------
# EventBridge: weekly schedule (Monday 08:00 UTC)
# -------------------------------------------------------
resource "aws_cloudwatch_event_rule" "weekly_digest" {
  name                = "${var.project_name}-weekly-digest"
  description         = "Trigger weekly knowledge base digest email"
  schedule_expression = "cron(0 8 ? * MON *)"
}

resource "aws_cloudwatch_event_target" "digest_lambda" {
  rule      = aws_cloudwatch_event_rule.weekly_digest.name
  target_id = "DigestLambda"
  arn       = aws_lambda_function.digest.arn
}

resource "aws_lambda_permission" "eventbridge_digest" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.digest.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.weekly_digest.arn
}

# -------------------------------------------------------
# CloudWatch Alarms
# -------------------------------------------------------
resource "aws_cloudwatch_metric_alarm" "presign_lambda_errors" {
  alarm_name          = "${var.project_name}-presign-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Presigned URL Lambda is throwing errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.presign.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "sidecar_lambda_errors" {
  alarm_name          = "${var.project_name}-sidecar-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = 60
  statistic           = "Sum"
  threshold           = 0
  alarm_description   = "Metadata sidecar Lambda is throwing errors"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.sidecar.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_latency" {
  alarm_name          = "${var.project_name}-api-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = 60
  statistic           = "p99"
  threshold           = 3000    # 3 seconds
  alarm_description   = "API Gateway p99 latency exceeds 3s"
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.main.name
    Stage   = aws_api_gateway_stage.main.stage_name
  }
}

# -------------------------------------------------------
# CloudWatch Dashboard
# -------------------------------------------------------
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-team0"

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric"
        properties = {
          title  = "Lambda Invocations & Errors"
          period = 300
          stat   = "Sum"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.presign.function_name],
            ["AWS/Lambda", "Errors",      "FunctionName", aws_lambda_function.presign.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.sidecar.function_name],
            ["AWS/Lambda", "Errors",      "FunctionName", aws_lambda_function.sidecar.function_name]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "API Gateway Latency (p99)"
          period  = 300
          stat    = "p99"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.main.name, "Stage", var.environment]
          ]
        }
      },
      {
        type = "metric"
        properties = {
          title   = "S3 Landing Bucket — Objects"
          period  = 86400
          stat    = "Average"
          metrics = [
            ["AWS/S3", "NumberOfObjects", "BucketName", module.storage.landing_bucket_id, "StorageType", "AllStorageTypes"]
          ]
        }
      }
    ]
  })
}
```

Add variables:

```hcl
variable "digest_sender_email" {
  description = "SES-verified sender address for the weekly digest"
  type        = string
  default     = "zoltan.szilagyi@accenture.com"
}

variable "digest_recipient_email" {
  description = "Email address to receive the weekly digest"
  type        = string
  default     = "zoltan.szilagyi@accenture.com"
}
```

### Acceptance Criteria

- [ ] SES email identity is verified — check spam/inbox for the AWS confirmation email and click the link
- [ ] `aws events put-events` or a manual Lambda test invocation sends the digest email successfully
- [ ] Email arrives with correct subject and body (document counts per Industry/Type)
- [ ] EventBridge rule shows next scheduled fire time in the console
- [x] CloudWatch dashboard `knowledge-base-team0` loads and shows Lambda invocation metrics
- [ ] Triggering 1+ Lambda errors causes the `knowledge-base-presign-errors` alarm to enter `ALARM` state within 1 minute

### Effort Estimate

**Day 3 afternoon** — Lambda + EventBridge + SES (~2h), CloudWatch alarms (~30min)

### Key Pitfalls

- SES in a new account is in **sandbox mode** — you can only send to verified email addresses. Both the sender AND recipient must be SES-verified during the hackathon. Request production access if needed (takes ~24h — do this Day 1)
- The digest Lambda does a full DynamoDB `Scan` — acceptable for the hackathon (small table), but add a note that this should become a GSI query for production
- EventBridge `cron` syntax is AWS-specific: `cron(0 8 ? * MON *)` — note the `?` in the day-of-month position (required when day-of-week is specified)
- The digest Lambda does not need to be inside the VPC (it accesses DynamoDB via Gateway endpoint and SES via the internet); omit `vpc_config` to avoid needing the VPC endpoint policy for SES

---

## Team 0 → Team 1 Handoff Checklist

Run this before Day 3 afternoon so Team 1 can finish their Bedrock Agent:

| Item | Command to verify | Status |
|------|------------------|--------|
| `bedrock_kb_id` output in state | `terraform output bedrock_kb_id` | |
| At least 3 docs indexed | `aws bedrock-agent-runtime retrieve --knowledge-base-id <id> --retrieval-query '{"text":"test"}'` returns results | |
| Metadata filter works | Add `filter: {"equals":{"key":"Industry","value":"Banking"}}` — only Banking docs returned | |
| `landing_bucket_name` output | `terraform output landing_bucket_name` | |
| S3 GetObject allowed for shim Lambda role | Confirm shim role ARN in landing bucket policy | |
| Metadata schema keys match exactly | `Industry`, `Type`, `Project`, `Client`, `Topic` — case-sensitive | |
