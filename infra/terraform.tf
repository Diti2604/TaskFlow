terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }
  backend "s3" {
     bucket = "my-tf-bucket-${var.account_id}"
     key = "backend"
     region = "us-east-1"

  }
}
