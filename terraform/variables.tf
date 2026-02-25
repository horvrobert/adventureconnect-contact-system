variable "sender_email" {
  description = "Verified SES sender email address"
  type        = string
}

variable "recipient_email" {
  description = "Verified SES recipient email address for contact form notifications"
  type        = string
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket for contact form submissions"
  type        = string
}
