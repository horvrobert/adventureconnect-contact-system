resource "aws_lambda_function" "notification_lambda" {
  filename      = "../lambda/notification_handler.zip"
  function_name = "adventureconnect-notification-handler"
  role          = aws_iam_role.notification_lambda_role.arn
  handler       = "notification_handler.lambda_handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 128

  environment {
    variables = {
      SENDER_EMAIL    = var.sender_email
      RECIPIENT_EMAIL = var.recipient_email
    }
  }

  tags = {
    Project   = "AdventureConnect"
    ManagedBy = "Terraform"
  }
}


resource "aws_lambda_event_source_mapping" "notification_lambda_stream" {
  event_source_arn  = aws_dynamodb_table.dynamodb.stream_arn
  function_name     = aws_lambda_function.notification_lambda.arn
  starting_position = "LATEST"

  tags = {
    Project   = "AdventureConnect"
    ManagedBy = "Terraform"
  }
}

