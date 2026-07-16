# Day 1 Hands-On Exercise: Deploy Your First AWS Resource

> **Duration:** 30–40 minutes
> **Goal:** Every participant runs `init`, `plan`, `apply`, and `destroy` successfully.
> **Pair up:** If you're new to Terraform, sit with someone experienced.

---

## Setup Check (2 min)

Before starting, verify your tools are working:

```bash
terraform --version   # Should show >= 1.7
aws sts get-caller-identity --profile hackathon   # Should show your account
```

If either fails, raise your hand — we'll sort it out.

---

## Exercise 1: Hello Terraform (10 min)

### Step 1: Create a working directory

```bash
mkdir ~/tf-exercise && cd ~/tf-exercise
```

### Step 2: Create `main.tf`

```hcl
terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region  = "eu-central-1"
  profile = "hackathon"
}

resource "aws_s3_bucket" "my_first_bucket" {
  bucket_prefix = "hackathon-${replace(lower(var.owner), " ", "-")}-"

  tags = {
    Project = "knowledge-base"
    Owner   = var.owner
  }
}

variable "owner" {
  description = "Your name (used in bucket naming)"
  type        = string
}

output "bucket_name" {
  description = "The name of the bucket that was created"
  value       = aws_s3_bucket.my_first_bucket.id
}
```

### Step 3: Create `terraform.tfvars`

```hcl
owner = "your-name-here"
```

Replace `your-name-here` with your actual name (lowercase, no spaces — e.g., `max-frohnholzer`).

### Step 4: Init, Plan, Apply

```bash
# Download the AWS provider
terraform init

# See what Terraform will create (nothing changes yet!)
terraform plan

# Create the bucket for real
terraform apply
```

When prompted, type `yes`.

### Step 5: Verify

```bash
# Check it exists in AWS
aws s3 ls --profile hackathon | grep hackathon

# Or check Terraform knows about it
terraform show
```

**Checkpoint:** You should see your bucket in the output. If you do — congrats, you just provisioned AWS infrastructure as code.

---

## Exercise 2: Modify the Resource (10 min)

Now let's see how Terraform handles changes.

### Step 1: Add encryption

Add this **below** your `aws_s3_bucket` resource in `main.tf`:

```hcl
resource "aws_s3_bucket_server_side_encryption_configuration" "my_first_bucket" {
  bucket = aws_s3_bucket.my_first_bucket.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}
```

### Step 2: Add public access block

```hcl
resource "aws_s3_bucket_public_access_block" "my_first_bucket" {
  bucket = aws_s3_bucket.my_first_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
```

### Step 3: Plan and apply

```bash
terraform plan    # Notice: it shows 2 resources to ADD, 0 to change, 0 to destroy
terraform apply
```

**Observe:** Terraform didn't recreate the bucket — it only added the new configuration on top. That's the declarative model at work.

### Step 4: Add another output

```hcl
output "bucket_arn" {
  description = "ARN of the bucket"
  value       = aws_s3_bucket.my_first_bucket.arn
}
```

```bash
terraform apply   # Just updates the output, no infra changes
```

---

## Exercise 3: Explore State (5 min)

```bash
# See everything Terraform is tracking
terraform state list

# See details of a specific resource
terraform state show aws_s3_bucket.my_first_bucket
```

**Key insight:** This state file is what Terraform uses to know what exists. Without it, Terraform would try to create everything from scratch.

---

## Exercise 4: Clean Up (5 min)

```bash
# Preview what will be destroyed
terraform plan -destroy

# Destroy everything
terraform destroy
```

Type `yes` when prompted.

```bash
# Verify it's gone
aws s3 ls --profile hackathon | grep hackathon
terraform state list   # Should be empty
```

**Clean up your exercise directory:**

```bash
cd ~ && rm -rf ~/tf-exercise
```

---

## Bonus Challenge (if you finish early)

Try one or more of these:

1. **Add a second bucket** and make one's name reference the other's ID
2. **Use `count`** to create 3 buckets at once: `count = 3` and `bucket_prefix = "hackathon-${var.owner}-${count.index}-"`
3. **Add a lifecycle rule** that transitions objects to Glacier after 90 days
4. **Break something on purpose** — manually delete the bucket in the AWS console, then run `terraform plan`. What happens?

---

## Key Takeaways

| You learned... | How it works |
|----------------|-------------|
| `init` | Downloads providers, sets up backend |
| `plan` | Safe preview — shows what WILL change |
| `apply` | Executes the plan, modifies real infrastructure |
| `destroy` | Removes everything Terraform manages |
| State | Terraform's memory of what exists |
| Declarative model | Describe desired state, Terraform figures out the steps |
| References | `resource_type.name.attribute` wires things together |

---

## What's Next

Now that you've seen the full cycle, you'll be working on real modules in your squad:
- **Alpha:** VPC, subnets, security groups in `terraform/modules/networking/`
- **Bravo:** S3 buckets, DynamoDB tables in `terraform/modules/storage/`
- **Charlie:** ECS cluster, ALB, ECR in `terraform/modules/compute/`

The skeleton code is already in the repo. Your job is to understand it, extend it, and make it work.

**Questions? Grab your squad lead or ask in the channel. Let's build.**
