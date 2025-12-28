# Web Scraping Infrastructure

Terraform infrastructure for running web scraping jobs on AWS EC2 (on-demand).

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        GitHub Actions                           │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │ terraform   │    │ run-scraper │    │ build-and-push      │ │
│  │ plan/apply  │    │ (on-demand) │    │ (web-scraping repo) │ │
│  └──────┬──────┘    └──────┬──────┘    └──────────┬──────────┘ │
└─────────┼──────────────────┼─────────────────────┼─────────────┘
          │                  │                     │
          ▼                  ▼                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                           AWS                                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐ │
│  │    VPC      │    │    ECR      │    │        S3           │ │
│  │  + Subnet   │    │  Docker     │    │  raw/players/       │ │
│  │  + IGW      │    │  Images     │    │  iceberg/           │ │
│  └──────┬──────┘    └──────┬──────┘    └──────────┬──────────┘ │
│         │                  │                      │             │
│         ▼                  ▼                      ▼             │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                     EC2 Instance                            ││
│  │  - Pulls Docker image from ECR                              ││
│  │  - Runs scraper                                             ││
│  │  - Uploads JSON to S3                                       ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

## Prerequisites

1. AWS CLI configured with credentials
2. Terraform >= 1.0
3. AWS SSH key pair created in the AWS Console

## Quick Start

### Step 1: Bootstrap (One-time setup)

Create S3 bucket and DynamoDB table for Terraform state:

```bash
cd bootstrap
terraform init
terraform apply
```

### Step 2: Deploy Infrastructure

```bash
cd environments/prod

# Update terraform.tfvars with your values:
# - ec2_key_name: your SSH key pair name
# - allowed_ssh_cidr: your IP address (e.g., "1.2.3.4/32")

terraform init
terraform plan
terraform apply
```

### Step 3: Run Scraper

SSH into EC2 and run:

```bash
ssh -i ~/.ssh/your-key.pem ec2-user@<EC2_PUBLIC_IP>
/home/ec2-user/scripts/run-scraper.sh
```

Or use the GitHub Actions workflow for automated on-demand scraping.

### Step 4: Destroy (when done)

```bash
terraform destroy
```

## Project Structure

```
web-scraping-infra/
├── bootstrap/              # S3 + DynamoDB for Terraform state
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── modules/
│   ├── vpc/               # VPC, subnet, internet gateway
│   ├── s3/                # S3 bucket for scraped data
│   ├── ecr/               # ECR repository for Docker images
│   ├── iam/               # IAM roles and policies
│   └── ec2/               # EC2 instance with user-data script
├── environments/
│   └── prod/              # Production environment
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       └── terraform.tfvars
└── .github/workflows/
    ├── terraform.yml      # Plan/Apply/Destroy infrastructure
    └── run-scraper.yml    # On-demand scraping job
```

## GitHub Actions Workflows

### terraform.yml
- **Trigger:** Push to main, PR, or manual
- **Actions:** Plan, Apply, Destroy (manual only)

### run-scraper.yml
- **Trigger:** Manual only
- **Flow:** Apply → Run Scraper → Destroy
- **Fully automated on-demand scraping**

## Required GitHub Secrets

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | AWS access key |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key |
| `EC2_SSH_PRIVATE_KEY` | SSH private key for EC2 access (not required if using SSM) |

## CI Integration (recommended)

This project runs the scraper on an EC2 instance via GitHub Actions. The recommended CI approach uses AWS Systems Manager (SSM) instead of SSH — this avoids storing SSH keys and works with instances in private subnets.

- What the workflow does:
    - `terraform apply` creates the EC2 instance and related resources.
    - The `run-scraper.yml` workflow uses Terraform output `instance_id` and calls `aws ssm send-command` to execute `/home/ec2-user/scripts/run-scraper.sh` on the instance.
    - The workflow polls `ssm get-command-invocation` until the command completes and then fetches stdout/stderr.

- Required GitHub Secrets for CI (SSM flow):
    - `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` — credentials for a GitHub Actions IAM user with permissions below.

- Minimal IAM permissions for GitHub Actions user (example):
    - `ssm:SendCommand`, `ssm:GetCommandInvocation`, `ssm:ListCommands`, `ssm:ListCommandInvocations`
    - `ec2:DescribeInstances` (optional, if you need to look up instance metadata)
    - `ecr:*` and `s3:*` permissions if the workflow also builds/pushes images or uploads artifacts

- Notes:
    - The EC2 instance must have the `AmazonSSMManagedInstanceCore` policy attached (this repo's Terraform attaches it).
    - The VPC must allow SSM traffic (we add interface VPC endpoints in the VPC module to avoid needing a NAT Gateway).
    - Once SSM is used, you can remove `EC2_SSH_PRIVATE_KEY` from GitHub Secrets and skip SSH steps in workflows.

If you want, I can tighten the IAM policies created by Terraform to scope them to fewer resources (recommended for production). 

## Cost Optimization

- EC2 runs only when needed (on-demand via GitHub Actions)
- `t3.micro` instance (~$0.01/hour)
- Destroy infrastructure after scraping completes
- S3 lifecycle policies can be added for old data cleanup
