resource "kubernetes_deployment_v1" "fastapi" {
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
          name              = "fastapi"
          image             = var.docker_image_uri
          image_pull_policy = "Always"

          port {
            container_port = 8000
          }

          # --- ADD THIS SECTION ---
          # Readiness probe checks if the container is ready to start accepting traffic.
          # The deployment is not considered successful until this probe passes.
          readiness_probe {
            http_get {
              path = "/" # Assuming your app serves a 200 OK on the root path
              port = 8000
            }
            initial_delay_seconds = 5
            period_seconds        = 10
          }

          # Liveness probe checks if the container is still running.
          # If this probe fails, Kubernetes will restart the container.
          liveness_probe {
            http_get {
              path = "/" # Assuming your app serves a 200 OK on the root path
              port = 8000
            }
            initial_delay_seconds = 15
            period_seconds        = 20
          }
          # --- END OF ADDED SECTION ---
        }
      }
    }
  }
}

