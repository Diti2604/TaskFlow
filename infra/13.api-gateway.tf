# resource "aws_apigatewayv2_api" "example" {
#   name          = "http-api"
#   protocol_type = "HTTP" 
# }

# resource "aws_apigatewayv2_integration" "example" {
#   api_id           = aws_apigatewayv2_api.example.id
#   credentials_arn  = aws_iam_role.example.arn
#   integration_type = "HTTP_PROXY"
#   integration_uri  = aws_lb_listener.example.arn

#   integration_method = "ANY"
#   connection_type    = "VPC_LINK"
#   connection_id      = aws_apigatewayv2_vpc_link.example.id

#   tls_config {
#     server_name_to_verify = "example.com"
#   }

#   request_parameters = {
#     "append:header.authforintegration" = "$context.authorizer.authorizerResponse"
#     "overwrite:path"                   = "staticValueForIntegration"
#   }

#   response_parameters {
#     status_code = 403
#     mappings = {
#       "append:header.auth" = "$context.authorizer.authorizerResponse"
#     }
#   }

#   response_parameters {
#     status_code = 200
#     mappings = {
#       "overwrite:statuscode" = "204"
#     }
#   }
# }