terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    mysql = {
      source  = "petoju/mysql" 
      version = "~> 3.0" 
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.38"
    }
    tls = { 
    source = "hashicorp/tls", version = "~> 4.0" 
    }
  }
  backend "s3" {
     bucket = "my-s3-bucket-083880123527"
     key = "backend"
     region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
  alias  = "us_east_1"
}