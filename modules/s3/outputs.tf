output "bucket_name" {
  description = "S3 bucket name"
  value       = aws_s3_bucket.data.id
}

output "bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.data.arn
}

output "bucket_regional_domain_name" {
  description = "S3 bucket regional domain name"
  value       = aws_s3_bucket.data.bucket_regional_domain_name
}
