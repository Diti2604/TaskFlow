resource "kubernetes_deployment" "fastapi" {
  depends_on = [ aws_eks_cluster.cluster1 ]
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
        }
      }
    }
  }
}