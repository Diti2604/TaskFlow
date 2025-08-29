resource "kubernetes_service" "example" {
  metadata {
    name = "fastapi-service"
  }
  spec {
    selector = {
      app = "fastapi"
    }
    port {
      port        = 80
      target_port = 8000
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}

resource "kubernetes_pod" "example" {
  metadata {
    name = "fastapi"
    labels = {
      app = "fastapi"
    }
  }

  spec {
    container {
      image = "${ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/fastapi-app}:latest"
      name  = "example"
    }
  }
}