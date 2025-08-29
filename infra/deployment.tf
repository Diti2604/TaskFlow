resource "kubernetes_deployment" "example" {
  metadata {
    name = "fastapi-deployment"
    labels = {
      app = "fastapi"
    }
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "fastapi"
      }
    }

    template {
      metadata {
        labels = {
          app = "fastapi"
        }
      }
      spec {
        container {
          image = "${var.account_id}.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:latest"
      
          name  = "fastapi"
          port {
            container_port = 8000
          }
          image_pull_policy = "Always"
        }
      }
    }
  }
}