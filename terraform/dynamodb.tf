resource "aws_dynamodb_table" "dynamodb" {
  name         = "adventureconnect-submissions"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "submissionId"

  attribute {
    name = "submissionId"
    type = "S"
  }

  tags = {
    Project   = "AdventureConnect"
    ManagedBy = "Terraform"
  }
}
