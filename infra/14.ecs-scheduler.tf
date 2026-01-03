# # ============= ECS SCHEDULER (9 AM - 5 PM CST) =============
# # Scales ECS service to 0 outside business hours to save costs
# # Uses EventBridge + Lambda to update ECS service desired count

# # Lambda execution role for ECS scheduler
# resource "aws_iam_role" "ecs_scheduler" {
#   name = "ecs-scheduler-lambda-role"

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

#   tags = {
#     Name = "ecs-scheduler-role"
#   }
# }

# # Lambda policy for ECS scaling and logging
# resource "aws_iam_role_policy" "ecs_scheduler_policy" {
#   name = "ecs-scheduler-policy"
#   role = aws_iam_role.ecs_scheduler.id

#   policy = jsonencode({
#     Version = "2012-10-17"
#     Statement = [
#       {
#         Effect = "Allow"
#         Action = [
#           "ecs:UpdateService",
#           "ecs:DescribeServices",
#           "logs:CreateLogGroup",
#           "logs:CreateLogStream",
#           "logs:PutLogEvents"
#         ]
#         Resource = "*"
#       }
#     ]
#   })
# }

# # Lambda function code for ECS scaling
# resource "aws_lambda_function" "ecs_scheduler" {
#   filename         = "${path.module}/lambda_ecs_scheduler.zip"
#   function_name    = "ecs-service-scheduler"
#   role             = aws_iam_role.ecs_scheduler.arn
#   handler          = "index.handler"
#   source_code_hash = filebase64sha256("${path.module}/lambda_ecs_scheduler.zip")
#   runtime          = "python3.11"
#   timeout          = 60

#   environment {
#     variables = {
#       CLUSTER_NAME = aws_ecs_cluster.main.name
#       SERVICE_NAME = aws_ecs_service.api.name
#       REGION       = var.aws_region
#     }
#   }

#   tags = {
#     Name = "ecs-scheduler-lambda"
#   }
# }

# # CloudWatch Log Group for Lambda
# resource "aws_cloudwatch_log_group" "ecs_scheduler" {
#   name              = "/aws/lambda/ecs-service-scheduler"
#   retention_in_days = 7

#   tags = {
#     Name = "ecs-scheduler-logs"
#   }
# }

# # ============= EVENTBRIDGE RULES =============

# # Scale DOWN at 5 PM CST (11 PM UTC)
# resource "aws_cloudwatch_event_rule" "ecs_scale_down" {
#   name                = "ecs-scale-down-5pm-cst"
#   description         = "Scale ECS service to 0 at 5 PM CST (11 PM UTC)"
#   schedule_expression = "cron(0 23 * * ? *)"  # 5 PM CST = 11 PM UTC

#   tags = {
#     Name = "ecs-scale-down-rule"
#   }
# }

# resource "aws_cloudwatch_event_target" "ecs_scale_down" {
#   rule      = aws_cloudwatch_event_rule.ecs_scale_down.name
#   target_id = "ECSScaleDown"
#   arn       = aws_lambda_function.ecs_scheduler.arn

#   input = jsonencode({
#     action        = "scale"
#     desired_count = 0
#   })
# }

# # Scale UP at 9 AM CST (3 PM UTC)
# resource "aws_cloudwatch_event_rule" "ecs_scale_up" {
#   name                = "ecs-scale-up-9am-cst"
#   description         = "Scale ECS service to 2 at 9 AM CST (3 PM UTC)"
#   schedule_expression = "cron(0 15 * * ? *)"  # 9 AM CST = 3 PM UTC

#   tags = {
#     Name = "ecs-scale-up-rule"
#   }
# }

# resource "aws_cloudwatch_event_target" "ecs_scale_up" {
#   rule      = aws_cloudwatch_event_rule.ecs_scale_up.name
#   target_id = "ECSScaleUp"
#   arn       = aws_lambda_function.ecs_scheduler.arn

#   input = jsonencode({
#     action        = "scale"
#     desired_count = 2
#   })
# }

# # ============= LAMBDA PERMISSIONS =============

# resource "aws_lambda_permission" "allow_eventbridge_scale_down" {
#   statement_id  = "AllowExecutionFromEventBridgeScaleDown"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.ecs_scheduler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.ecs_scale_down.arn
# }

# resource "aws_lambda_permission" "allow_eventbridge_scale_up" {
#   statement_id  = "AllowExecutionFromEventBridgeScaleUp"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.ecs_scheduler.function_name
#   principal     = "events.amazonaws.com"
#   source_arn    = aws_cloudwatch_event_rule.ecs_scale_up.arn
# }

# # ============= OUTPUTS =============
# output "ecs_scheduler_function_name" {
#   description = "Name of the ECS scheduler Lambda function"
#   value       = aws_lambda_function.ecs_scheduler.function_name
# }

# output "scale_down_time" {
#   description = "When ECS scales down (CST)"
#   value       = "5:00 PM CST (11:00 PM UTC)"
# }

# output "scale_up_time" {
#   description = "When ECS scales up (CST)"
#   value       = "9:00 AM CST (3:00 PM UTC)"
# }
