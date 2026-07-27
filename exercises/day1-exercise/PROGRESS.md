# Day 1 Exercise — Progress Log

> **Participant:** Zoltan Szilagyi (`zoltan.szilagyi@accenture.com`)
> **Date:** 2026-07-27
> **Exercise file:** `docs/day1-hands-on-exercise.md`

---

## Variables

| Variable | Value | Set in |
|----------|-------|--------|
| `owner` | `zoltan-szilagyi` | `terraform.tfvars` |
| AWS region | `eu-central-1` | `main.tf` provider block |
| AWS profile | `hackathon` | `main.tf` provider block |

---

## Files Created

| File | Purpose |
|------|---------|
| `main.tf` | S3 bucket + encryption + public-access-block + outputs |
| `terraform.tfvars` | Sets `owner = "zoltan-szilagyi"` |

### `terraform.tfvars`

```hcl
owner = "zoltan-szilagyi"
```

### Expected bucket name pattern

```
hackathon-zoltan-szilagyi-<random-suffix>
```

Terraform appends a random suffix because `bucket_prefix` is used instead of `bucket`, avoiding name collisions between participants.

---

## Step-by-Step Results

### Setup Check

```
$ terraform --version
Terraform v1.x.x    ✅

$ aws --version
aws-cli/2.36.8      ✅ (installed 2026-07-27)

$ aws sts get-caller-identity --profile hackathon
❌ — AWS profile "hackathon" not configured yet (see blocker below)
```

---

### Exercise 1 — Hello Terraform

#### Step: `terraform init`

```
$ terraform init

Initializing the backend...

Initializing provider plugins...
- Finding hashicorp/aws versions matching "~> 5.0"...
- Installing hashicorp/aws v5.100.0...
- Installed hashicorp/aws v5.100.0 (signed by HashiCorp)

Terraform has been successfully initialized!
```

**Status: ✅ COMPLETE**

---

#### Step: `terraform validate`

```
$ terraform validate

Success! The configuration is valid.
```

**Status: ✅ COMPLETE**

---

#### Step: `terraform plan`

```
$ terraform plan

Error: failed to get shared config profile, hackathon
  with provider["registry.terraform.io/hashicorp/aws"],
  on main.tf line 12, in provider "aws":
  12:   profile = "hackathon"
```

**Status: ❌ BLOCKED — AWS credentials not configured**

See [Blocker](#blocker--aws-credentials) section below.

---

#### Steps: `terraform apply`, `terraform show` — PENDING

Waiting for credentials before proceeding.

---

### Exercise 2 — Modify the Resource

The `main.tf` already includes the Exercise 2 resources (added upfront):
- `aws_s3_bucket_server_side_encryption_configuration.my_first_bucket` — AES256
- `aws_s3_bucket_public_access_block.my_first_bucket` — all four blocks enabled
- `output "bucket_arn"` added

**Status: ⏳ PENDING — waiting for credentials to apply**

---

### Exercise 3 — Explore State

Commands to run after apply:

```bash
terraform state list
terraform state show aws_s3_bucket.my_first_bucket
```

**Status: ⏳ PENDING**

---

### Exercise 4 — Clean Up

Commands to run at the end:

```bash
terraform plan -destroy
terraform destroy
aws s3 ls --profile hackathon | grep hackathon   # should be empty
terraform state list                              # should be empty
```

**Status: ⏳ PENDING**

---

## Blocker — AWS Credentials

The `main.tf` provider block uses `profile = "hackathon"`. This profile must exist in `~/.aws/config`.

### To unblock: configure the `hackathon` profile

**Option A — AWS SSO (IAM Identity Center)**

Run in a terminal (requires interactive browser login):

```powershell
aws configure sso --profile hackathon
# Enter the SSO start URL from the hackathon kick-off email
# SSO region: eu-central-1
# Default output format: json
```

Then log in once per session:

```powershell
aws sso login --profile hackathon
```

**Option B — Static access keys**

If an organizer gives you `AWS_ACCESS_KEY_ID` + `AWS_SECRET_ACCESS_KEY`:

```powershell
aws configure --profile hackathon
# AWS Access Key ID: <paste>
# AWS Secret Access Key: <paste>
# Default region: eu-central-1
# Default output format: json
```

**Option C — Environment variables (no profile needed)**

Remove `profile = "hackathon"` from `main.tf`, then set:

```powershell
$env:AWS_ACCESS_KEY_ID     = "<key>"
$env:AWS_SECRET_ACCESS_KEY = "<secret>"
$env:AWS_SESSION_TOKEN     = "<token>"   # if using temporary creds
$env:AWS_DEFAULT_REGION    = "eu-central-1"
terraform plan
```

---

## Expected Plan Output (once credentials are available)

```
Terraform will perform the following actions:

  # aws_s3_bucket.my_first_bucket will be created
  + resource "aws_s3_bucket" "my_first_bucket" {
      + bucket_prefix = "hackathon-zoltan-szilagyi-"
      + id            = (known after apply)
      + tags = {
          + "Owner"   = "zoltan-szilagyi"
          + "Project" = "knowledge-base"
        }
    }

  # aws_s3_bucket_server_side_encryption_configuration.my_first_bucket will be created
  + resource "aws_s3_bucket_server_side_encryption_configuration" "my_first_bucket" {
      + bucket = (known after apply)
      + rule {
          + apply_server_side_encryption_by_default {
              + sse_algorithm = "AES256"
            }
        }
    }

  # aws_s3_bucket_public_access_block.my_first_bucket will be created
  + resource "aws_s3_bucket_public_access_block" "my_first_bucket" {
      + bucket                  = (known after apply)
      + block_public_acls       = true
      + block_public_policy     = true
      + ignore_public_acls      = true
      + restrict_public_buckets = true
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + bucket_arn  = (known after apply)
  + bucket_name = (known after apply)
```

---

## Checklist

| Step | Command | Status |
|------|---------|--------|
| Install AWS CLI | `winget install Amazon.AWSCLI` | ✅ Done (v2.36.8) |
| Install Terraform | already installed | ✅ Done |
| Create `main.tf` | — | ✅ Done |
| Create `terraform.tfvars` | — | ✅ Done (owner = zoltan-szilagyi) |
| `terraform init` | provider downloaded | ✅ Done |
| `terraform validate` | config valid | ✅ Done |
| Configure `hackathon` AWS profile | `aws configure sso` | ❌ Needs SSO URL |
| `terraform plan` | preview 3 resources | ⏳ Pending credentials |
| `terraform apply` | create S3 bucket | ⏳ Pending credentials |
| `terraform state list` | verify state | ⏳ Pending apply |
| `terraform destroy` | clean up | ⏳ Pending apply |
