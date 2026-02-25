resource "aws_s3_bucket" "contact_form_bucket" {
  bucket = var.s3_bucket_name

  tags = {
    Name      = "AdventureConnect-Contact-Form-Bucket"
    ManagedBy = "Terraform"
  }
}

resource "aws_s3_bucket_public_access_block" "contact_form_bucket_public_access_block" {
  bucket = aws_s3_bucket.contact_form_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}




resource "aws_s3_bucket_policy" "contact_form_bucket_policy" {
  bucket = aws_s3_bucket.contact_form_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "s3:GetObject"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Resource = "${aws_s3_bucket.contact_form_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.contact_form_distribution.arn
          }
        }
      }
    ]
  })
}
