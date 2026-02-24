resource "aws_dynamodb_table" "dynamodb" {
  name             = "adventureconnect-submissions"
  billing_mode     = "PAY_PER_REQUEST"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  hash_key         = "submissionId"

  attribute {
    name = "submissionId"
    type = "S"
  }

  tags = {
    Project   = "AdventureConnect"
    ManagedBy = "Terraform"
  }
}
