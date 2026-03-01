# REST API base configuration
resource "aws_api_gateway_rest_api" "contact_form_api" {
  name        = "adventureconnect-api"
  description = "Contact form API"
  endpoint_configuration {
    types = ["REGIONAL"]
  }

  tags = {
    Name      = "AdventureConnect-API"
    ManagedBy = "Terraform"
  }
}


# Resource [URL Path]
resource "aws_api_gateway_resource" "contact_resource" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  parent_id   = aws_api_gateway_rest_api.contact_form_api.root_resource_id
  path_part   = "submit"
}


# Method [POST]
resource "aws_api_gateway_method" "submit_post" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "POST"
  authorization = "NONE"
}


# Lambda Integration
resource "aws_api_gateway_integration" "lambda_integration" {
  rest_api_id             = aws_api_gateway_rest_api.contact_form_api.id
  resource_id             = aws_api_gateway_resource.contact_resource.id
  http_method             = aws_api_gateway_method.submit_post.http_method
  type                    = "AWS_PROXY"
  integration_http_method = "POST"
  uri                     = aws_lambda_function.lambda_function.invoke_arn
}


# OPTIONS Method [CORS Preflight]
resource "aws_api_gateway_method" "submit_options" {
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  resource_id   = aws_api_gateway_resource.contact_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}


# OPTIONS Integration [Mock Response]
resource "aws_api_gateway_integration" "lambda_options_integration" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.submit_options.http_method
  type        = "MOCK"

  request_templates = {
    "application/json" = jsonencode({
      statusCode = 200
    })
  }
}


# Method Response for OPTIONS [Defines what the method CAN return]
resource "aws_api_gateway_method_response" "submit_options_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.submit_options.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = true
    "method.response.header.Access-Control-Allow-Methods" = true
    "method.response.header.Access-Control-Allow-Headers" = true
  }
}


# Integration Response for OPTIONS [Actual CORS header values]
resource "aws_api_gateway_integration_response" "submit_options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id
  resource_id = aws_api_gateway_resource.contact_resource.id
  http_method = aws_api_gateway_method.submit_options.http_method
  status_code = aws_api_gateway_method_response.submit_options_response.status_code

  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
    "method.response.header.Access-Control-Allow-Methods" = "'POST,OPTIONS'"
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'"
  }
}


# Lambda Permission [Inbound Access - allows API Gateway to invoke Lambda]
resource "aws_lambda_permission" "api_gateway_lambda_permission" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda_function.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.contact_form_api.execution_arn}/*/*"
}


# Deployment + Stage
resource "aws_api_gateway_deployment" "contact_form_deployment" {
  rest_api_id = aws_api_gateway_rest_api.contact_form_api.id

  triggers = {
    redeployment = sha1(jsonencode([
      aws_api_gateway_resource.contact_resource.id,
      aws_api_gateway_method.submit_post.id,
      aws_api_gateway_method.submit_options.id,
      aws_api_gateway_integration.lambda_integration.id,
      aws_api_gateway_integration.lambda_options_integration.id,
      aws_api_gateway_method_response.submit_options_response.id,
      aws_api_gateway_integration_response.submit_options_integration_response.id,
    ]))
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "contact_form_stage" {
  deployment_id = aws_api_gateway_deployment.contact_form_deployment.id
  rest_api_id   = aws_api_gateway_rest_api.contact_form_api.id
  stage_name    = "prod"

  tags = {
    Name      = "AdventureConnect-Prod-Stage"
    ManagedBy = "Terraform"
  }
}


# Usage Plan [Rate Limiting - Critical for cost protection]
resource "aws_api_gateway_usage_plan" "contact_form_usage_plan" {
  name        = "adventureconnect-usage-plan"
  description = "Usage plan for contact form - rate limiting for cost protection"

  quota_settings {
    limit  = 1000
    period = "DAY"
  }

  throttle_settings {
    burst_limit = 10
    rate_limit  = 5
  }

  api_stages {
    api_id = aws_api_gateway_rest_api.contact_form_api.id
    stage  = aws_api_gateway_stage.contact_form_stage.stage_name
  }

  tags = {
    Name      = "AdventureConnect-Usage-Plan"
    ManagedBy = "Terraform"
  }
}


