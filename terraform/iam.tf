resource "aws_iam_role" "lambda_role" {
  name = "adventureconnect-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name      = "AdventureConnect-Lambda-Role"
    ManagedBy = "Terraform"
  }
}


resource "aws_iam_role_policy_attachment" "lambda_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = aws_iam_policy.lambda_dynamodb_policy.arn
}

# Custom inline policy for DynamoDB access to Lambda PutItem, GetItem
resource "aws_iam_policy" "lambda_dynamodb_policy" {
  name = "adventureconnect-lambda-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:PutItem",
          "dynamodb:GetItem"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.dynamodb.arn
      }
    ]
  })

  tags = {
    Name      = "AdventureConnect-Lambda-DynamoDB-Policy"
    ManagedBy = "Terraform"
  }
}

