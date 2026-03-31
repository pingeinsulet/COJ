# Bootstrap uses local state so we can create the remote state buckets.
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.28"
    }
  }
}
