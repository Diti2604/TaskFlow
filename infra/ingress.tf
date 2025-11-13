resource "kubernetes_ingress_v1" "fastapi" {
  metadata {
    name      = "fastapi-ingress"
    namespace = "default"
    annotations = {
      "kubernetes.io/ingress.class"              = "alb"
      "alb.ingress.kubernetes.io/scheme"         = "internet-facing"
      "alb.ingress.kubernetes.io/listen-ports"   = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn"= aws_acm_certificate_validation.cert.certificate_arn
      "alb.ingress.kubernetes.io/target-type"    = "ip" 
      "alb.ingress.kubernetes.io/healthcheck-path"= "/"
      "alb.ingress.kubernetes.io/tags"           = "app=fastapi,ingress-name=fastapi-ingress"
    }
    }            
  spec {
    ingress_class_name = "alb"
    rule {
      http {
        path {
          path      = "/"
          path_type = "Prefix"
          backend {
            service {
              name = "fastapi-service"
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
resource "aws_iam_role" "alb_controller_sa" {
  name = "alb-controller-sa-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Federated = aws_iam_openid_connect_provider.cluster.arn },
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringEquals = {
          "${replace(aws_iam_openid_connect_provider.cluster.url, "https://", "")}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "alb_controller_attach" {
  role       = aws_iam_role.alb_controller_sa.name
  policy_arn = aws_iam_policy.eks-alb-policy.arn
}
resource "kubernetes_service_account" "alb_controller" {
  metadata {
    name      = "aws-load-balancer-controller"
    namespace = "kube-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.alb_controller_sa.arn
    }
  }
  automount_service_account_token = true
}

resource "time_sleep" "pre_alb_buffer" {
  depends_on      = [aws_eks_cluster.cluster1]
  create_duration = "1m"
}

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [kubernetes_service_account.alb_controller, time_sleep.pre_alb_buffer]
  values = [yamlencode({
    clusterName = var.cluster_name
    region      = var.aws_region
    vpcId       = aws_vpc.my-vpc.id
    serviceAccount = {
      create = false
      name   = kubernetes_service_account.alb_controller.metadata[0].name
    }
  })]
}

 
resource "aws_iam_role" "fastapi_pod_identity" {
  name = "fastapi-pod-identity-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Sid       = "AllowEksAuthToAssumeRoleForPodIdentity",
      Effect    = "Allow",
      Principal = { Service = "pods.eks.amazonaws.com" },
      Action    = ["sts:AssumeRole", "sts:TagSession"]
    }]
  })
}


resource "aws_iam_role_policy_attachment" "fastapi_pod_identity_attach" {
  role       = aws_iam_role.fastapi_pod_identity.name
  policy_arn = aws_iam_policy.fastapi_sm_kms.arn
}

resource "aws_iam_policy" "fastapi_sm_kms" {
  name        = "fastapi-secretsmanager-read"
  description = "FastAPI pod may read the RDS master secret + decrypt with KMS"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid: "ReadSecret",
        Effect: "Allow",
        Action: ["secretsmanager:GetSecretValue","secretsmanager:DescribeSecret"],
        Resource: aws_db_instance.database-1.master_user_secret[0].secret_arn
      },
      {
        Sid: "KmsDecrypt",
        Effect: "Allow",
        Action: ["kms:Decrypt"],
        Resource: aws_kms_key.secrets-manager-password.arn
      }
    ]
  })
}


resource "kubernetes_service_account" "secrets_manager_sa" {
  metadata {
    name      = "secrets-manager-sa"
    namespace = "default"
  }
  automount_service_account_token = true
}


resource "aws_eks_pod_identity_association" "fastapi" {
  cluster_name    = var.cluster_name
  namespace       = "default"
  service_account = kubernetes_service_account.secrets_manager_sa.metadata[0].name
  role_arn        = aws_iam_role.fastapi_pod_identity.arn
}

