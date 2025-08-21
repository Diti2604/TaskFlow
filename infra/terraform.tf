terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.28" }
    helm       = { source = "hashicorp/helm",       version = "~> 2.13" }
  }
}
provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster1.endpoint
}
provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster1.endpoint
  }
}