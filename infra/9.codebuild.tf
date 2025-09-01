# data "aws_iam_policy_document" "assume_role" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["codebuild.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "CODEBUILD-ROLE" {
#   name               = "CODEBUILD-ROLE"
#   assume_role_policy = data.aws_iam_policy_document.assume_role.json
# }

# resource "aws_iam_role_policy_attachment" "secrets-manager-policy" {
#   policy_arn = "arn:aws:iam::aws:policy/SecretsManagerReadWrite"
#   role       = aws_iam_role.CODEBUILD-ROLE.name
# }

# data "aws_iam_policy_document" "CODEBUILD-ROLE" {
#   statement {
#     effect = "Allow"

#     actions = [
#       "logs:CreateLogGroup",
#       "logs:CreateLogStream",
#       "logs:PutLogEvents",
#     ]
#     resources = ["*"]
#   }

#   statement {
#     effect = "Allow"

#     actions = [
#       "s3:PutObject",
#       "s3:GetObject",
#       "s3:GetObjectVersion",
#       "s3:GetBucketAcl",
#       "s3:GetBucketLocation"
#     ]

#     resources = ["arn:aws:s3:::codepipeline-us-east-1-*"]
#   }
# }

# resource "aws_iam_role_policy" "CODEBUILD-ROLE" {
#   role   = aws_iam_role.CODEBUILD-ROLE.name
#   policy = data.aws_iam_policy_document.CODEBUILD-ROLE.json
# }

# resource "aws_codebuild_project" "CODEBUILD-PROJECT" {
#   name          = "eks-codebuild"
#   description   = "CI/CD pipeline component of my 3-tier website project"
#   build_timeout = 5
#   service_role  = aws_iam_role.CODEBUILD-ROLE.arn

#   artifacts {
#     type = "NO_ARTIFACTS"
#   }

#   cache {
#     type  = "LOCAL"
#     modes = ["LOCAL_DOCKER_LAYER_CACHE", "LOCAL_SOURCE_CACHE", "LOCAL_CUSTOM_CACHE"]
#   }

#   environment {
#     compute_type                = "BUILD_GENERAL1_SMALL"
#     image                       = "aws/codebuild/amazonlinux2-x86_64-standard:5.0"
#     type                        = "LINUX_CONTAINER"
#     image_pull_credentials_type = "CODEBUILD"
#   }

#   logs_config {
#     cloudwatch_logs {
#       group_name  = "log-group"
#       stream_name = "log-stream"
#     }
#   }

#   source {
#     type            = "GITHUB"
#     location        = "https://github.com/Diti2604/aws-codepipeline-backend.git"
#     git_clone_depth = 1
#   }
# }


# resource "aws_iam_policy" "codebuild-ecr-policy" {
#   name        = "CODEBUILD-ECR"
#   description = "NECESSARY POLICY FOR CODEBUILD TO INTERACT WITH ECR"
#   policy = jsonencode({
#     "Version" : "2012-10-17",
#     "Statement" : [
#       {
#         "Effect" : "Allow",
#         "Action" : [
#           "ecr:GetAuthorizationToken",
#           "ecr:BatchCheckLayerAvailability",
#           "ecr:InitiateLayerUpload",
#           "ecr:UploadLayerPart",
#           "ecr:CompleteLayerUpload",
#           "ecr:PutImage",
#           "ecr:BatchGetImage",
#           "ecr:GetDownloadUrlForLayer",
#           "ecr:CreateRepository"
#         ],
#         "Resource" : "*"
#       }
#     ]
#     }
#   )
# }

# resource "aws_iam_role_policy_attachment" "CODEBUILD-ROLE-ECR-ATTACHMENT" {
#   policy_arn = aws_iam_policy.codebuild-ecr-policy.arn
#   role       = aws_iam_role.CODEBUILD-ROLE.name
# }


# resource "aws_iam_policy" "CODEBUILD-EKS" {
#   name        = "CODEBUILD-EKS"
#   description = "NECESSARY POLICY FOR CODEBUILD TO INTERACT WITH EKS"
#   policy = jsonencode({
#     "Version" : "2012-10-17",
#     "Statement" : [
#       {
#         "Effect" : "Allow",
#         "Action" : [
#           "eks:DescribeCluster",
#           "sts:AssumeRole"
#         ],
#         "Resource" : "*"
#       },
#       {
#         "Effect" : "Allow",
#         "Action" : [
#           "elasticloadbalancing:*",
#           "ec2:DescribeSubnets",
#           "ec2:DescribeSecurityGroups"
#         ],
#         "Resource" : "*"
#       },
#       {
#         "Sid" : "AccessKubernetesApi",
#         "Effect" : "Allow",
#         "Action" : [
#           "eks:AccessKubernetesApi"
#         ],
#         "Resource" : "*"
#       },
#     ]
#     }
#   )

# }

# resource "aws_iam_role_policy_attachment" "CODEBUILD-ROLE-EKS-ATTACHMENT" {
#   policy_arn = aws_iam_policy.CODEBUILD-EKS.arn
#   role       = aws_iam_role.CODEBUILD-ROLE.name
# }


