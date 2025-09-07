# resource "kubernetes_service" "fastapi" {
#   metadata {
#     name = "fastapi-service"
#     namespace = "default"
#     labels = {
#       app = "fastapi"
#     }
#   }

#   spec {
#     type = "ClusterIP"

#     selector = {
#       app = "fastapi"
#     }

#     port {
#       protocol    = "TCP"
#       port        = 80
#       target_port = 8000
#     }
#   }
#   depends_on = [kubernetes_deployment_v1.fastapi]
# }