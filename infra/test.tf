# # IAM policy limited to the single RDS master secret
# resource "aws_iam_policy" "db_secret_read" {
#   name        = "eks-db-bootstrap-read-secret"
#   description = "Allow reading the RDS master secret"
#   policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect   = "Allow",
#       Action   = ["secretsmanager:GetSecretValue"],
#       Resource = aws_db_instance.database-1.master_user_secret[0].secret_arn
#     }]
#   })
# }

# # IRSA role trusted only for the specific ServiceAccount we'll create:
# #   namespace: default
# #   service account name: db-bootstrap-sa
# resource "aws_iam_role" "db_bootstrap_irsa" {
#   name = "eks-db-bootstrap-irsa"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [{
#       Effect = "Allow",
#       Principal = {
#         Federated = aws_iam_openid_connect_provider.cluster.arn
#       },
#       Action = "sts:AssumeRoleWithWebIdentity",
#       Condition = {
#         StringEquals = {
#           # IMPORTANT: left side must be "<OIDC issuer without https://>:sub"
#           # The provider's "url" includes https://, Terraform provider strips it internally for this key.
#           # Use replace() to remove the "https://" prefix in HCL:
#           "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:default:db-bootstrap-sa"
#         }
#       }
#     }]
#   })
# }

# resource "aws_iam_role_policy_attachment" "db_bootstrap_attach" {
#   role       = aws_iam_role.db_bootstrap_irsa.name
#   policy_arn = aws_iam_policy.db_secret_read.arn
# }


# # ---------- Kubernetes resources (Terraform) ----------
# resource "kubernetes_service_account_v1" "db_bootstrap_sa" {
#   metadata {
#     name      = "db-bootstrap-sa"
#     namespace = "default"
#     annotations = {
#       "eks.amazonaws.com/role-arn" = aws_iam_role.db_bootstrap_irsa.arn
#     }
#   }
# }

# resource "kubernetes_config_map_v1" "users_sql" {
#   metadata {
#     name      = "users-bootstrap-sql"
#     namespace = "default"
#   }

#   data = {
#     "init.sql" = <<-EOT
#       CREATE DATABASE IF NOT EXISTS database_1;
#       USE database_1;
#       CREATE TABLE IF NOT EXISTS users (
#         id INT AUTO_INCREMENT PRIMARY KEY,
#         name VARCHAR(255) NOT NULL,
#         password VARCHAR(255) NOT NULL
#       );
#     EOT
#   }
# }

# resource "kubernetes_job_v1" "create_users_table" {
#   metadata {
#     name      = "create-users-table"
#     namespace = "default"
#   }

#   spec {
#     backoff_limit = 2

#     template {
#       metadata {}
#       spec {
#         service_account_name = kubernetes_service_account_v1.db_bootstrap_sa.metadata[0].name
#         restart_policy       = "Never"

#         volume {
#           name = "work"
#           empty_dir {}
#         }
#         volume {
#           name = "sql"
#           config_map {
#             name = kubernetes_config_map_v1.users_sql.metadata[0].name
#             items {
#               key  = "init.sql"
#               path = "init.sql"
#             }
#           }
#         }

#         init_container {
#           name  = "fetch-secret"
#           image = "public.ecr.aws/aws-cli/aws-cli:2.17.33"
#           command = ["/bin/sh","-c"]
#           args = [<<-SH
#             set -euo pipefail
#             aws secretsmanager get-secret-value --secret-id "$SECRET_ARN" --query SecretString --output text > /work/secret.json
#             PASS=$(jq -r '.password' /work/secret.json)
#             USER=$(jq -r '.username' /work/secret.json)
#             printf "%s" "$PASS" > /work/password
#             printf "%s" "$USER" > /work/username
#           SH
#           ]
#           env {
#             name  = "AWS_REGION"
#             value = var.aws_region
#           }
#           env {
#             name  = "SECRET_ARN"
#             value = aws_db_instance.database-1.master_user_secret[0].secret_arn
#           }
#           volume_mount {
#             name       = "work"
#             mount_path = "/work"
#           }
#         }

#         container {
#           name  = "mysql-client"
#           image = "mysql:8.0"
#           command = ["/bin/sh","-c"]
#           args = [<<-SH
#             set -euo pipefail
#             USER=$(cat /work/username)
#             PASS=$(cat /work/password)

#             echo "Waiting for MySQL on ${RDS_ENDPOINT}:3306 ..."
#             for i in $(seq 1 60); do
#               mysqladmin ping -h "$RDS_ENDPOINT" -u"$USER" -p"$PASS" --silent && break
#               sleep 5
#             done

#             echo "Running bootstrap SQL..."
#             mysql -h "$RDS_ENDPOINT" -u"$USER" -p"$PASS" < /sql/init.sql
#             echo "Done."
#           SH
#           ]
#           env {
#             name  = "RDS_ENDPOINT"
#             value = aws_db_instance.database-1.address
#           }
#           volume_mount {
#             name       = "work"
#             mount_path = "/work"
#           }
#           volume_mount {
#             name       = "sql"
#             mount_path = "/sql"
#           }
#         }
#       }
#     }
#   }

#   # Make sure the job only runs after the DB is ready and the IRSA role exists
#   depends_on = [
#     aws_db_instance.database-1,
#     aws_iam_role_policy_attachment.db_bootstrap_attach
#   ]
# }
