# S3 backend in us-east-2. Create bucket/table once via: cd environments/bootstrap && terraform apply
terraform {
  backend "s3" {
    bucket         = "jenkins-blue-green-tfstate-nonprod"
    key            = "jenkins-nonprod/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "jenkins-blue-green-tfstate-nonprod"
    encrypt        = true
  }
}
