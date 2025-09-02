

resource "kubernetes_ingress_v1" "fastapi" {
  metadata {
    name = "fastapi-ingress"
    annotations = {
      "kubernetes.io/ingress.class"            = "alb"
      "alb.ingress.kubernetes.io/scheme"        = "internal"
      "alb.ingress.kubernetes.io/listen-ports"  = "[{\"HTTP\":80},{\"HTTPS\":443}]"
      "alb.ingress.kubernetes.io/certificate-arn" = aws_acm_certificate.cert-base.arn
      "alb.ingress.kubernetes.io/target-type"   = "ip"
      "alb.ingress.kubernetes.io/tags" = "ingress-name=fastapi-ingress"
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

resource "helm_release" "aws_lb_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  depends_on = [kubernetes_service_account.alb_controller]

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

