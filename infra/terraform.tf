terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }
  backend "s3" {
     bucket = "my-s3-bucket-992382398009"
     key = "backend"
     region = "us-east-1"
  }
}
