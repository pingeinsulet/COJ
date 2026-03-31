variable "bucket_prefix" {
  description = "Prefix for S3 bucket and DynamoDB table names (must be globally unique for S3)."
  type        = string
  default     = "jenkins-blue-green"
}

variable "aws_region" {
  description = "AWS region for state resources (use us-east-2)."
  type        = string
  default     = "us-east-2"
}
