resource "aws_iam_role" "notification_lambda_role" {
  name = "adventureconnect-notification-lambda-role"

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
    Name      = "AdventureConnect-Notification-Lambda-Role"
    ManagedBy = "Terraform"
  }
}


resource "aws_iam_role_policy_attachment" "notification_lambda_policy_attachment" {
  role       = aws_iam_role.notification_lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "notification_lambda_dynamodb_policy_attachment" {
  role       = aws_iam_role.notification_lambda_role.name
  policy_arn = aws_iam_policy.notification_lambda_dynamodb_policy.arn
}

# Custom inline policy for DynamoDB Stream
resource "aws_iam_policy" "notification_lambda_dynamodb_policy" {
  name = "adventureconnect-notification-lambda-dynamodb-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "dynamodb:GetRecords",
          "dynamodb:GetShardIterator",
          "dynamodb:DescribeStream",
          "dynamodb:ListStreams"
        ]
        Effect   = "Allow"
        Resource = aws_dynamodb_table.dynamodb.stream_arn
      }
    ]
  })

  tags = {
    Name      = "AdventureConnect-Notification-Lambda-DynamoDB-Policy"
    ManagedBy = "Terraform"
  }
}


resource "aws_iam_policy" "notification_ses_policy" {
  name = "adventureconnect-notification-ses-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = [
          "ses:SendEmail"
        ]
        Effect   = "Allow"
        Resource = "*"
      }
    ]
  })

  tags = {
    Name      = "AdventureConnect-Notification-SES-Policy"
    ManagedBy = "Terraform"
  }
}


resource "aws_iam_role_policy_attachment" "notification_ses_policy_attachment" {
  role       = aws_iam_role.notification_lambda_role.name
  policy_arn = aws_iam_policy.notification_ses_policy.arn
}
