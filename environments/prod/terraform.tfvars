# Environment-specific values
# IMPORTANT: Do NOT commit sensitive values to git!

aws_region        = "eu-central-1"
environment       = "prod"
project_name      = "web-scraping"

# S3 bucket for scraped data (using existing bucket)
s3_bucket_name    = "eu-central-1-web-scraping-data"

# EC2 configuration
ec2_instance_type = "t3.micro"
ec2_key_name      = "web-scraping-key"  # Create this key pair in AWS console first

# SSH access - replace with your IP
allowed_ssh_cidr  = "0.0.0.0/0"  # CHANGE THIS to your IP, e.g., "203.0.113.50/32"
