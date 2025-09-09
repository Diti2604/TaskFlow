# OIDC provider for your EKS cluster (you likely already have this for the ALB controller)
data "aws_iam_openid_connect_provider" "eks" {
  arn = aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

# Allow read of just your DB secret
resource "aws_iam_policy" "secrets_read" {
  name        = "eks-secretsmanager-read-dbsecret"
  description = "Allow pods to read the RDS secret"
  policy      = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["secretsmanager:GetSecretValue"],
      Resource = aws_secretsmanager_secret.rds_master.arn
    }]
  })
}

resource "aws_iam_role" "db_migrator_irsa" {
  name = "db-migrator-irsa"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = data.aws_iam_openid_connect_provider.eks.arn
      },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          # Replace with your cluster’s issuer hostpath
          "${replace(data.aws_iam_openid_connect_provider.eks.url, "https://", "")}:sub" = "system:serviceaccount:default:db-migrator-sa"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "attach" {
  role       = aws_iam_role.db_migrator_irsa.name
  policy_arn = aws_iam_policy.secrets_read.arn
}
