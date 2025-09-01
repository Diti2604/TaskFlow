# resource "kubernetes_deployment" "fastapi" {
#   depends_on = [ aws_ecr_repository.ecr ]
#   metadata {
#     name = "fastapi-deployment"
#     labels = {
#       app = "fastapi"
#     }
#   }

#   spec {
#     replicas = 2

#     selector {
#       match_labels = {
#         app = "fastapi"
#       }
#     }

#     template {
#       metadata {
#         labels = {
#           app = "fastapi"
#         }
#       }

#       spec {
#         container {
#           name              = "fastapi"
#           image             = "${var.account_id}.dkr.ecr.us-east-1.amazonaws.com/fastapi-app:latest"
#           image_pull_policy = "Always"   
#           port {
#             container_port = 8000
#           }
#         }
#       }
#     }
#   }
# }