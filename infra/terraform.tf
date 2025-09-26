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
  }
  backend "s3" {
     bucket = "my-s3-bucket-533267026736"
     key = "backend"
     region = "us-east-1"
  }
}
