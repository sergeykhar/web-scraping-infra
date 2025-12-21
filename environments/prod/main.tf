terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Terraform state backend (run bootstrap first!)
  backend "s3" {
    bucket         = "skharybin-terraform-state"
    key            = "web-scraping/prod/terraform.tfstate"
    region         = "eu-central-1"
    encrypt        = true
    dynamodb_table = "terraform-locks"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

# VPC Module
module "vpc" {
  source = "../../modules/vpc"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
  aws_region   = var.aws_region
}

# S3 Module
module "s3" {
  source = "../../modules/s3"

  project_name = var.project_name
  environment  = var.environment
  bucket_name  = var.s3_bucket_name
}

# ECR Module
module "ecr" {
  source = "../../modules/ecr"

  project_name    = var.project_name
  environment     = var.environment
  repository_name = "web-scraping"
}

# IAM Module
module "iam" {
  source = "../../modules/iam"

  project_name       = var.project_name
  environment        = var.environment
  s3_bucket_arn      = module.s3.bucket_arn
  ecr_repository_arn = module.ecr.repository_arn
}

# EC2 Module
module "ec2" {
  source = "../../modules/ec2"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.vpc.vpc_id
  subnet_id             = module.vpc.public_subnet_id
  instance_profile_name = module.iam.ec2_instance_profile_name
  instance_type         = var.ec2_instance_type
  key_name              = var.ec2_key_name
  allowed_ssh_cidr      = var.allowed_ssh_cidr

  # Pass configuration to EC2 user data
  aws_region     = var.aws_region
  ecr_repository = module.ecr.repository_url
  s3_bucket      = module.s3.bucket_name
}
