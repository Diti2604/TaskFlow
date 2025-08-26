terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }
  backend "s3" {
     bucket = "cmdk"
     key = "backend"
     region = "us-east-1"
  }
}
