terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }
  backend "s3" {
     bucket = "backend-terraform-329458323-9146ty245y21321"
     key = "backend"
     region = "us-east-1"

  }
}
