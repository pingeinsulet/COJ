output "state_bucket_names" {
  description = "S3 bucket name for each environment's Terraform state."
  value       = { for k, b in aws_s3_bucket.state : k => b.bucket }
}

output "lock_table_names" {
  description = "DynamoDB table name for each environment's state lock."
  value       = { for k, t in aws_dynamodb_table.lock : k => t.name }
}

output "backend_config" {
  description = "Example backend block for each environment."
  value = {
    for env in local.envs : env => {
      bucket         = aws_s3_bucket.state[env].bucket
      key            = "jenkins-${env}/terraform.tfstate"
      region         = var.aws_region
      dynamodb_table = aws_dynamodb_table.lock[env].name
      encrypt        = true
    }
  }
}
