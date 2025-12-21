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
| `EC2_SSH_PRIVATE_KEY` | SSH private key for EC2 access |

## Cost Optimization

- EC2 runs only when needed (on-demand via GitHub Actions)
- `t3.micro` instance (~$0.01/hour)
- Destroy infrastructure after scraping completes
- S3 lifecycle policies can be added for old data cleanup
