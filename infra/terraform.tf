terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    
  }
  backend "s3" {
     bucket = "my-state-file-bucket-058264477174"
     key = "backend"
     region = "us-east-1"
  }
}
