variable "aws_region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  type        = string
  default     = "skharybin-web-scraping-tf-state"
}

variable "lock_table_name" {
  description = "DynamoDB table name for state locking"
  type        = string
  default     = "terraform-locks"
}
