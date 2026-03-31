# S3 backend in us-east-2. Create bucket/table once via: cd environments/bootstrap && terraform apply
terraform {
  backend "s3" {
    bucket         = "jenkins-blue-green-tfstate-prod"
    key            = "jenkins-prod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "jenkins-blue-green-tfstate-prod"
    encrypt        = true
  }
}
