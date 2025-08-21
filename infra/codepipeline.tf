# resource "aws_codepipeline" "codepipeline" {
#   name     = "eks-pipeline"
#   role_arn = aws_iam_role.codepipeline_role.arn

#   artifact_store {
#     location = aws_s3_bucket.s3_bucket.bucket
#     type     = "S3"

#     encryption_key {
#       id   = aws_kms_key.s3kmskey.arn
#       type = "KMS"
#     }
#   }

#   stage {
#     name = "Source"

#     action {
#       name             = "Source"
#       category         = "Source"
#       owner            = "AWS"
#       provider         = "CodeStarSourceConnection"
#       version          = "1"
#       output_artifacts = ["source_output"]

#       configuration = {
#         ConnectionArn    = aws_codestarconnections_connection.connection.arn
#         FullRepositoryId = "Diti2604/aws-codepipeline-backend"
#         BranchName       = "backend"
#       }
#     }
#   }

#   stage {
#     name = "Build"

#     action {
#       name             = "Build"
#       category         = "Build"
#       owner            = "AWS"
#       provider         = "CodeBuild"
#       input_artifacts  = ["source_output"]
#       output_artifacts = ["build_output"]
#       version          = "1"

#       configuration = {
#         ProjectName = aws_codebuild_project.CODEBUILD-PROJECT.name
#       }
#     }
#   }


# }

# resource "aws_codestarconnections_connection" "connection" {
#   name          = "connection"
#   provider_type = "GitHub"
# }

# data "aws_iam_policy_document" "assume_role-codepipeline" {
#   statement {
#     effect = "Allow"

#     principals {
#       type        = "Service"
#       identifiers = ["codepipeline.amazonaws.com"]
#     }

#     actions = ["sts:AssumeRole"]
#   }
# }

# resource "aws_iam_role" "codepipeline_role" {
#   name               = "CodePipeline-Role"
#   path = "/service-role/"
#   assume_role_policy = data.aws_iam_policy_document.assume_role-codepipeline.json
# }

# data "aws_iam_policy_document" "codepipeline_policy" {
#   statement {
#     effect = "Allow"

#     actions = [
#       "s3:GetObject",
#       "s3:GetObjectVersion",
#       "s3:GetBucketVersioning",
#       "s3:PutObjectAcl",
#       "s3:PutObject",
#     ]

#     resources = [
#       aws_s3_bucket.s3_bucket.arn,
#       "${aws_s3_bucket.s3_bucket.arn}/*"
#     ]
#   }
#   statement {
#     effect = "Allow"

#     actions = [
#       "s3:PutObject",
#       "s3:PutObjectAcl",
#       "s3:GetObject",
#       "s3:GetObjectVersion"
#     ]

#     resources = [
#       aws_codepipeline.codepipeline.arn,
#       "${aws_codepipeline.codepipeline.arn}/*"
#     ]
#   }


# }

# resource "aws_iam_role_policy" "codepipeline_policy" {
#   name   = "codepipeline_policy"
#   role   = aws_iam_role.codepipeline_role.id
#   policy = data.aws_iam_policy_document.codepipeline_policy.json
# }

# # data "aws_kms_alias" "s3kmskey" {
# #   name                     = "alias/s3kmskey"
# # }

# resource "aws_kms_key" "s3kmskey" {
#   description              = "KMS Key"
#   customer_master_key_spec = "SYMMETRIC_DEFAULT"
#   enable_key_rotation      = false
#   is_enabled               = true
#   key_usage                = "ENCRYPT_DECRYPT"
#   multi_region             = false
# }

