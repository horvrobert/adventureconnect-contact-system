resource "aws_cloudfront_origin_access_control" "contact_form_oac" {
  name                              = "contact-form-oac"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "contact_form_distribution" {
  enabled             = true
  default_root_object = "index.html"


  origin {
    domain_name              = aws_s3_bucket.contact_form_bucket.bucket_regional_domain_name
    origin_id                = aws_s3_bucket.contact_form_bucket.id
    origin_access_control_id = aws_cloudfront_origin_access_control.contact_form_oac.id
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = aws_s3_bucket.contact_form_bucket.id
    viewer_protocol_policy = "redirect-to-https"
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name      = "AdventureConnect-Contact-Form-Distribution"
    ManagedBy = "Terraform"
  }
}
