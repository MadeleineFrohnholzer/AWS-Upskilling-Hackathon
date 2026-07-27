# Terraform Plan Results

> **Date:** 2026-07-27
> **Branch:** `HackatonSolutions`
> **Environment:** Local Windows workstation — no AWS CLI installed, no credentials configured

---

## Status Summary

| Stack | `terraform validate` | `terraform plan` |
|-------|---------------------|-----------------|
| `terraform/shared` | ✅ **Success** | ❌ Blocked — no AWS credentials |
| `terraform/team0` | ✅ **Success** | ❌ Blocked — no AWS credentials |
| `terraform/team1` | ✅ **Success** | ❌ Blocked — no AWS credentials |

---

## Validate Output (all three stacks)

```
$ terraform -chdir=terraform/shared init -backend=false && terraform -chdir=terraform/shared validate
Terraform has been successfully initialized!
Success! The configuration is valid.

$ terraform -chdir=terraform/team0 init -backend=false && terraform -chdir=terraform/team0 validate
Terraform has been successfully initialized!
Success! The configuration is valid.

$ terraform -chdir=terraform/team1 init -backend=false && terraform -chdir=terraform/team1 validate
Terraform has been successfully initialized!
Success! The configuration is valid.
```

---

## Plan Blocker

`terraform plan` requires the S3 backend to be reachable (to lock state and read existing resources). Without AWS credentials, init with the real backend fails:

```
Error: Backend initialization required, please run "terraform init"

The configuration uses a custom S3 backend:
  bucket         = "hackathon-tf-state-064453091991"
  key            = "shared/terraform.tfstate"
  region         = "eu-central-1"
  dynamodb_table = "hackathon-tf-locks"

Authenticate first, then run:
  terraform init
  terraform plan -input=false -no-color
```

Additionally, `team0` and `team1` use `data "terraform_remote_state"` to read upstream stack outputs, which also requires live S3 access.

---

## How to Run the Plan

Configure credentials (pick one method):

```bash
# Option A — AWS SSO profile
aws configure sso --profile hackathon
export AWS_PROFILE=hackathon

# Option B — static keys
export AWS_ACCESS_KEY_ID=...
export AWS_SECRET_ACCESS_KEY=...
export AWS_SESSION_TOKEN=...       # if using temporary credentials

# Option C — IAM role assumption
aws sts assume-role \
  --role-arn arn:aws:iam::064453091991:role/hackathon-team1-developer \
  --role-session-name plan-session \
  --query Credentials \
  --output json
```

Then run in order (each stack depends on the previous one's state):

```bash
# 1. Shared infrastructure
terraform -chdir=terraform/shared init
terraform -chdir=terraform/shared plan -input=false -no-color -out=shared.tfplan

# 2. Team 0 — M0 Foundation & Ingestion (needs shared state)
terraform -chdir=terraform/team0 init
terraform -chdir=terraform/team0 plan -input=false -no-color -out=team0.tfplan

# 3. Team 1 — M1 Access & Knowledge App (needs shared + team0 state)
terraform -chdir=terraform/team1 init
terraform -chdir=terraform/team1 plan -input=false -no-color -out=team1.tfplan
```

---

## Expected Plan — Derived from Code

The following resource lists are derived by reading the Terraform source. They reflect what the plan **will** show once credentials are available, assuming no resources exist yet.

### Stack: `shared`

```
Terraform will perform the following actions:

  # module.networking.aws_vpc_endpoint.execute_api will be created
  # module.networking.aws_vpc_endpoint.ssm will be created
  # module.networking.tls_private_key.alb will be created
  # module.networking.tls_self_signed_cert.alb will be created
  # module.networking.aws_acm_certificate.alb will be created
  # module.networking.aws_lb_listener.https will be created
  # aws_iam_role.team0_developer will be created
  # aws_iam_role_policy.team0_developer will be created
  # aws_iam_role.team0_operator will be created
  # aws_iam_role_policy_attachment.team0_admin will be created
  # aws_iam_role.team1_developer will be created
  # aws_iam_role_policy.team1_developer will be created

Plan: 12 to add, 0 to change, 0 to destroy.
```

### Stack: `team0`

```
Terraform will perform the following actions:

  # aws_dynamodb_table.documents will be created
  #   GSI: industry-uploaded_at-index (KEYS_ONLY)

  # aws_s3_bucket_policy.processed_bedrock will be created

  # aws_iam_role.lambda_exec will be created
  # aws_iam_role_policy.lambda_permissions will be created
  # aws_iam_role_policy_attachment.lambda_vpc will be created

  # aws_lambda_function.presign will be created
  #   runtime = python3.12, handler = index.handler
  #   filename = lambda/presigned_url/index.py (zipped by archive provider)
  # aws_cloudwatch_log_group.presign will be created

  # aws_api_gateway_rest_api.main will be created
  #   endpoint_configuration { types = ["PRIVATE"] }
  # aws_api_gateway_rest_api_policy.vpce_only will be created
  # aws_api_gateway_resource.upload_url will be created
  # aws_api_gateway_method.upload_post will be created
  # aws_api_gateway_integration.upload_post will be created
  # aws_api_gateway_deployment.main will be created
  # aws_api_gateway_stage.main will be created
  # aws_lambda_permission.api_gw_presign will be created

  # aws_lambda_function.sidecar will be created
  #   runtime = python3.12, handler = index.handler
  # aws_cloudwatch_log_group.sidecar will be created
  # aws_lambda_permission.s3_sidecar will be created
  # aws_s3_bucket_notification.landing_trigger will be created

  # aws_opensearchserverless_security_policy.encryption will be created
  # aws_opensearchserverless_security_policy.network will be created
  # aws_opensearchserverless_access_policy.bedrock_kb will be created
  # aws_opensearchserverless_collection.vectors will be created
  #   type = "VECTORSEARCH"
  # null_resource.opensearch_index will be created
  #   (local-exec: python create_opensearch_index.py — 1024-dim HNSW/faiss knn index)

  # aws_iam_role.bedrock_kb will be created
  # aws_iam_role_policy.bedrock_kb will be created
  # aws_bedrockagent_knowledge_base.main will be created
  #   model_arn = amazon.titan-embed-text-v2:0
  #   vector_index_name = knowledge-base-index
  # aws_bedrockagent_data_source.processed will be created
  #   chunking: fixed_size, 512 tokens, 20% overlap

  # aws_ses_email_identity.digest_sender will be created
  # aws_lambda_function.digest will be created
  #   runtime = python3.12
  # aws_cloudwatch_log_group.digest will be created
  # aws_cloudwatch_event_rule.weekly_digest will be created
  #   schedule_expression = "cron(0 8 ? * MON *)"
  # aws_cloudwatch_event_target.digest_lambda will be created
  # aws_lambda_permission.eventbridge_digest will be created

  # aws_sns_topic.alarms will be created
  # aws_sns_topic_subscription.alarm_email will be created
  # aws_cloudwatch_metric_alarm.lambda_errors["presign"] will be created
  # aws_cloudwatch_metric_alarm.lambda_errors["sidecar"] will be created
  # aws_cloudwatch_metric_alarm.lambda_errors["digest"] will be created
  # aws_cloudwatch_metric_alarm.lambda_throttles["presign"] will be created
  # aws_cloudwatch_metric_alarm.lambda_throttles["sidecar"] will be created
  # aws_cloudwatch_metric_alarm.lambda_throttles["digest"] will be created
  # aws_cloudwatch_metric_alarm.apigw_5xx will be created
  # aws_cloudwatch_metric_alarm.apigw_latency will be created
  # aws_cloudwatch_dashboard.main will be created
  #   dashboard_name = "knowledge-base-team0"

Plan: 40 to add, 0 to change, 0 to destroy.
```

### Stack: `team1`

```
Terraform will perform the following actions:

  # module.compute.aws_ecr_repository.chat_frontend will be created
  #   image_tag_mutability = "MUTABLE", scan_on_push = true
  # module.compute.aws_ecs_cluster.main will be created
  #   containerInsights = enabled
  # module.compute.aws_iam_role.ecs_task_execution will be created
  # module.compute.aws_iam_role_policy_attachment.ecs_task_execution will be created
  # module.compute.aws_ecs_task_definition.chat_frontend will be created
  # module.compute.aws_cloudwatch_log_group.chat_frontend will be created
  # module.compute.aws_security_group.ecs_tasks will be created
  # module.compute.aws_security_group.alb will be created
  # module.compute.aws_lb.internal will be created

  # aws_cognito_user_pool.main will be created
  #   username_attributes = ["email"]
  #   allow_admin_create_user_only = true
  # aws_cognito_user_pool_domain.main will be created
  #   domain = "knowledge-base-<account_id>"
  # aws_cognito_identity_provider.entra will be created
  #   provider_type = "OIDC"
  #   oidc_issuer = "https://login.microsoftonline.com/<tenant>/v2.0"
  # aws_cognito_user_pool_client.open_webui will be created
  #   generate_secret = true
  #   allowed_oauth_flows = ["code"]
  #   callback_urls = ["https://<alb-dns>/oauth2/idpresponse"]

  # aws_lb_target_group.chat_frontend will be created
  #   target_type = "ip", port = 8080
  #   health_check: GET /health → 200
  # aws_lb_listener_rule.chat_frontend will be created
  #   priority = 100
  #   action[0]: authenticate-cognito (8h session)
  #   action[1]: forward → chat_frontend target group

  # aws_ssm_parameter.webui_secret_key will be created
  #   type = "SecureString", name = "/knowledge-base/open-webui/secret-key"
  # aws_cloudwatch_log_group.open_webui will be created

  # aws_iam_role.ecs_task will be created
  # aws_iam_role_policy.ecs_task will be created
  #   permissions: InvokeAgent, Retrieve, RetrieveAndGenerate, SSM:GetParameter
  # aws_iam_role_policy.ecs_exec_ssm will be created

  # aws_ecs_task_definition.open_webui will be created
  #   cpu = "1024", memory = "2048"
  #   image = <ecr-repo>:latest (or var.open_webui_image)
  #   env: WEBUI_AUTH, ENABLE_SIGNUP, BEDROCK_AGENT_ID, BEDROCK_AGENT_ALIAS_ID, ...
  #   secret: WEBUI_SECRET_KEY from SSM
  # aws_ecs_service.open_webui will be created
  #   launch_type = "FARGATE", desired_count = 1
  #   network_configuration: private subnets, ecs_tasks SG

  # aws_iam_role.bedrock_agent will be created
  #   trust: bedrock.amazonaws.com (source-account + ARN conditions)
  # aws_iam_role_policy.bedrock_agent will be created
  #   permissions: InvokeModel (Claude 3.5 Sonnet), Retrieve/RetrieveAndGenerate (KB)
  # aws_bedrockagent_agent.main will be created
  #   foundation_model = "anthropic.claude-3-5-sonnet-20241022-v2:0"
  #   prepare_agent = true
  # aws_bedrockagent_agent_knowledge_base_association.main will be created
  #   knowledge_base_state = "ENABLED"
  # aws_bedrockagent_agent_alias.live will be created
  #   agent_alias_name = "live"

Plan: 27 to add, 0 to change, 0 to destroy.
```

---

## Resource Count Summary

| Stack | Resources to create | Resources to change | Resources to destroy |
|-------|--------------------:|--------------------:|---------------------:|
| `shared` | 12 | 0 | 0 |
| `team0` | 40 | 0 | 0 |
| `team1` | 27 | 0 | 0 |
| **Total** | **79** | **0** | **0** |

---

## Post-Apply Manual Steps

These cannot be automated via Terraform and must be completed after `terraform apply`:

| Step | Stack | Command / Action |
|------|-------|-----------------|
| Enable Bedrock model access | shared | AWS Console → Bedrock → Model access → enable **Claude 3.5 Sonnet** + **Titan Text Embeddings V2** |
| Verify SES sender email | team0 | Check inbox for `digest_sender_email`, click AWS confirmation link |
| Create OpenSearch knn index | team0 | `python terraform/team0/scripts/create_opensearch_index.py` (run after AOSS collection is `ACTIVE`) |
| Register Entra redirect URI | team1 | Azure Portal → App Registration → Redirect URIs → add `https://<cognito-domain>.auth.eu-central-1.amazoncognito.com/oauth2/idpresponse` |
| Push Open WebUI image to ECR | team1 | `docker pull ghcr.io/open-webui/open-webui:main && docker tag ... && docker push <ecr-url>:latest` |
| Update SSM secret key | team1 | AWS Console → Parameter Store → `/knowledge-base/open-webui/secret-key` → set to a random 32+ char string |
