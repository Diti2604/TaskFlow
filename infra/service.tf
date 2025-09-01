resource "kubernetes_service" "fastapi" {
  metadata {
    name = "fastapi-service"
    labels = {
      app = "fastapi"
    }
  }

  spec {
    type = "ClusterIP"

    selector = {
      app = "fastapi"
    }

    port {
      name        = "http"
      protocol    = "TCP"
      port        = 80
      target_port = 8000
    }
  }
  depends_on = [kubernetes_deployment.fastapi]
}