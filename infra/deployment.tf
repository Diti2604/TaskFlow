resource "kubernetes_deployment_v1" "fastapi" {
  metadata {
    name = "fastapi-deployment"
    namespace = var.k8s_namespace
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
          name              = "fastapi"
          image             = var.docker_image_uri
          image_pull_policy = "Always"

          port {
            container_port = 8000
          }
        }
      }
    }
  }
  timeouts {
    create = "15m"
    update = "15m"
  }
}

