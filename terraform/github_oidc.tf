# OIDC Identity Provider for GitHub Actions
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = [
    "sts.amazonaws.com"
  ]

  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd"
  ]
}

# IAM Role that GitHub Actions will assume
resource "aws_iam_role" "github_actions" {
  name = "adventureconnect-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = aws_iam_openid_connect_provider.github.arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringLike = {
            "token.actions.githubusercontent.com:sub" = "repo:horvrobert/adventureconnect-contact-system:*"
          }
          StringEquals = {
            "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })
}

# Policy giving GitHub Actions role enough permissions to run Terraform
resource "aws_iam_role_policy" "github_actions" {
  name = "adventureconnect-github-actions-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # S3 state bucket access
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          # DynamoDB locking
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem",
          # All services Terraform manages in this project
          "lambda:*",
          "apigateway:*",
          "dynamodb:*",
          "s3:*",
          "cloudfront:*",
          "cloudwatch:*",
          "sns:*",
          "ses:*",
          "iam:*",
          "logs:*"
        ]
        Resource = "*"
      }
    ]
  })
}
