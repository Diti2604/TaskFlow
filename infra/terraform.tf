terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }
  backend "s3" {
     bucket = "my-backend-bucket-34572630948302531413"
     key = "backend"
     region = "us-east-1"

  }
}
