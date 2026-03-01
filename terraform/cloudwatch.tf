resource "aws_sns_topic" "alerts" {
  name = "adventureconnect-alerts"
}

resource "aws_sns_topic_subscription" "alerts_email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.recipient_email
}

resource "aws_cloudwatch_metric_alarm" "contact_handler_errors" {
  alarm_name          = "adventureconnect-contact-handler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  alarm_description   = "Contact handler Lambda errors detected"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "notification_handler_errors" {
  alarm_name          = "adventureconnect-notification-handler-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Errors"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  alarm_description   = "Notification handler Lambda errors detected"
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.notification_lambda.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "lambda_duration_alarm" {
  alarm_name          = "adventureconnect-contact-handler-duration"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Duration"
  namespace           = "AWS/Lambda"
  period              = "60"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "Alarm when Lambda function duration exceeds 1 second"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    FunctionName = aws_lambda_function.lambda_function.function_name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_latency" {
  alarm_name          = "adventureconnect-api-gateway-latency"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "Latency"
  namespace           = "AWS/ApiGateway"
  period              = "60"
  statistic           = "Average"
  threshold           = "1000"
  alarm_description   = "Alarm when API Gateway latency exceeds 1 second"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.contact_form_api.name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_5xx_errors" {
  alarm_name          = "adventureconnect-api-gateway-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "5XXError"
  namespace           = "AWS/ApiGateway"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alarm when API Gateway 5XX errors detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.contact_form_api.name
  }
}

resource "aws_cloudwatch_metric_alarm" "api_gateway_4xx_errors" {
  alarm_name          = "adventureconnect-api-gateway-4xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "4XXError"
  namespace           = "AWS/ApiGateway"
  period              = "60"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "Alarm when API Gateway 4XX errors detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    ApiName = aws_api_gateway_rest_api.contact_form_api.name
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_system_errors" {
  alarm_name          = "adventureconnect-dynamodb-system-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "SystemErrors"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alarm when DynamoDB system errors detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.dynamodb.name
  }
}

resource "aws_cloudwatch_metric_alarm" "dynamodb_throttled_requests" {
  alarm_name          = "adventureconnect-dynamodb-throttled-requests"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "ThrottledRequests"
  namespace           = "AWS/DynamoDB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "0"
  alarm_description   = "Alarm when DynamoDB throttled requests detected"
  alarm_actions       = [aws_sns_topic.alerts.arn]
  treat_missing_data  = "notBreaching"

  dimensions = {
    TableName = aws_dynamodb_table.dynamodb.name
  }
}



resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "adventureconnect-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        width  = 8
        height = 6
        properties = {
          title  = "Lambda - Errors"
          region = "eu-central-1"
          metrics = [
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.lambda_function.function_name],
            ["AWS/Lambda", "Errors", "FunctionName", aws_lambda_function.notification_lambda.function_name]
          ]
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        properties = {
          title  = "Lambda - Duration"
          region = "eu-central-1"
          metrics = [
            ["AWS/Lambda", "Duration", "FunctionName", aws_lambda_function.lambda_function.function_name]
          ]
          stat   = "Average"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        properties = {
          title  = "Lambda - Invocations"
          region = "eu-central-1"
          metrics = [
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.lambda_function.function_name],
            ["AWS/Lambda", "Invocations", "FunctionName", aws_lambda_function.notification_lambda.function_name]
          ]
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        properties = {
          title  = "API Gateway - Latency"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApiGateway", "Latency", "ApiName", aws_api_gateway_rest_api.contact_form_api.name]
          ]
          stat   = "Average"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        properties = {
          title  = "API Gateway - 5XX Errors"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApiGateway", "5XXError", "ApiName", aws_api_gateway_rest_api.contact_form_api.name]
          ]
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 8
        height = 6
        properties = {
          title  = "API Gateway - 4XX Errors"
          region = "eu-central-1"
          metrics = [
            ["AWS/ApiGateway", "4XXError", "ApiName", aws_api_gateway_rest_api.contact_form_api.name]
          ]
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB - System Errors"
          region = "eu-central-1"
          metrics = [
            ["AWS/DynamoDB", "SystemErrors", "TableName", aws_dynamodb_table.dynamodb.name]
          ]
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
        }
      },
      {
        type   = "metric"
        width  = 12
        height = 6
        properties = {
          title  = "DynamoDB - Throttled Requests"
          region = "eu-central-1"
          metrics = [
            ["AWS/DynamoDB", "ThrottledRequests", "TableName", aws_dynamodb_table.dynamodb.name]
          ]
          stat   = "Sum"
          period = 60
          view   = "timeSeries"
        }
      }
    ]
  })
}
