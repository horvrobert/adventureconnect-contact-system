resource "aws_lambda_function" "lambda_function" {
  filename      = "../lambda/lambda_function.zip"
  function_name = "adventureconnect-contact-handler"
  role          = aws_iam_role.lambda_role.arn
  handler       = "lambda_function.lambda_handler"
  runtime       = "python3.11"
  timeout       = 10
  memory_size   = 128

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.dynamodb.name
    }
  }
}
