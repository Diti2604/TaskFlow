# # ============= EKS SCHEDULER (9 AM - 5 PM CST) =============
# # Scales EKS node group to 0 outside business hours to save costs

# # Lambda execution role
# resource "aws_iam_role" "eks_scheduler" {
#   name = "eks-scheduler-lambda-role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [{
#       Action = "sts:AssumeRole"
#       Effect = "Allow"
#       Principal = {
#         Service = "lambda.amazonaws.com"
#       }
#     }]
#   })
# }

# # Lambda policy for EKS scaling
# resource "aws_iam_role_policy" "eks_scheduler_policy" {
#   name = "eks-scheduler-policy"
#   role = aws_iam_role.eks_scheduler.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "eks:UpdateNodegroupConfig",
#           "eks:DescribeNodegroup",
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# # Lambda function code
# resource "aws_lambda_function" "eks_scheduler" {
#   filename         = "${path.module}/lambda_eks_scheduler.zip"
#   function_name    = "eks-node-scheduler"
#   role             = aws_iam_role.eks_scheduler.arn
#   handler          = "index.handler"
#   source_code_hash = filebase64sha256("${path.module}/lambda_eks_scheduler.zip")
#   runtime          = "python3.11"
#   timeout          = 60

#   environment {
#     variables = {
#       CLUSTER_NAME    = var.cluster_name
#       NODE_GROUP_NAME = var.node_group_name
#       AWS_REGION      = var.aws_region
#     }
#   }
# }

# # CloudWatch Event Rule - Scale DOWN at 5 PM CST (11 PM UTC)
# resource "aws_cloudwatch_event_rule" "eks_scale_down" {
#   name                = "eks-scale-down-5pm-cst"
#   description         = "Scale EKS nodes to 0 at 5 PM CST"
#   schedule_expression = "cron(0 23 * * ? *)"  # 5 PM CST = 11 PM UTC (CST = UTC-6)
# }

# resource "aws_cloudwatch_event_target" "eks_scale_down" {
#   rule      = aws_cloudwatch_event_rule.eks_scale_down.name
#   target_id = "EKSScaleDown"
#   arn       = aws_lambda_function.eks_scheduler.arn
#   input = jsonencode({
#     action       = "scale"
#     desired_size = 0
#     min_size     = 0
#     max_size     = 0
#   })
# }

# # CloudWatch Event Rule - Scale UP at 9 AM CST (3 PM UTC)
# resource "aws_cloudwatch_event_rule" "eks_scale_up" {
#   name                = "eks-scale-up-9am-cst"
#   description         = "Scale EKS nodes to 1 at 9 AM CST"
#   schedule_expression = "cron(0 15 * * ? *)"  # 9 AM CST = 3 PM UTC
# }

# resource "aws_cloudwatch_event_target" "eks_scale_up" {
#   rule      = aws_cloudwatch_event_rule.eks_scale_up.name
#   target_id = "EKSScaleUp"
#   arn       = aws_lambda_function.eks_scheduler.arn
#   input = jsonencode({
#     action       = "scale"
#     desired_size = 1
#     min_size     = 1
#     max_size     = 2
#   })
# }

# # Lambda permissions for CloudWatch Events
# resource "aws_lambda_permission" "allow_cloudwatch_scale_down" {
#   statement_id  = "AllowExecutionFromCloudWatchScaleDown"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.eks_scheduler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.eks_scale_down.arn
# }

# resource "aws_lambda_permission" "allow_cloudwatch_scale_up" {
#   statement_id  = "AllowExecutionFromCloudWatchScaleUp"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.eks_scheduler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.eks_scale_up.arn
# }

# # CloudWatch Log Group for Lambda
# resource "aws_cloudwatch_log_group" "eks_scheduler" {
#   name              = "/aws/lambda/eks-node-scheduler"
#   retention_in_days = 7
# }
