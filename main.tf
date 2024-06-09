# S3 stuff

resource "aws_s3_bucket" "b" {
  bucket = var.s3_bucket_name
  # (Optional, Forces new resource) Name of the bucket. 
  # If omitted, Terraform will assign a random, unique name.

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}

/*
resource "aws_s3_object" "object" {
  bucket = var.s3_bucket_name
  key    = "new_object_key"
  source = "path/to/file"

  # The filemd5() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the md5() function and the file() function:
  # etag = "${md5(file("path/to/file"))}"
  etag = filemd5("path/to/file")
}
*/

# upload everything from to-upload/
resource "aws_s3_object" "upload_files" {
  for_each   = fileset("to-upload/", "**")
  bucket     = var.s3_bucket_name
  key        = "${var.file_path}/${each.value}"
  source     = "to-upload/${each.value}"
  depends_on = [aws_s3_bucket.b] # so it attemps to upload only after the bucket exists
}


# CLOUDFRONT stuff

resource "aws_s3_bucket_policy" "allow_cloudfront_access" {
  bucket = aws_s3_bucket.b.id

  # Ik, this policy sounds kinda fishy, but idk man...
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action   = "s3:GetObject"
        Effect   = "Allow"
        Resource = "${aws_s3_bucket.b.arn}/*"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = "arn:aws:cloudfront::${data.aws_caller_identity.current.account_id}:distribution/${aws_cloudfront_distribution.s3_distribution.id}"
          }
        }
      }
    ]
  })
  depends_on = [aws_s3_bucket.b] # only after bucket exists
}

data "aws_caller_identity" "current" {}


locals {
  s3_origin_id = "myS3Origin"
}

resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "my-bucket-origin-access-control"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name              = aws_s3_bucket.b.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
    origin_id                = local.s3_origin_id
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "CDN for my bucket"
  default_root_object = "index.html" # yup you can use this to serve static websites too


  # tbh, no ideia what most of this stuff is doing but hey, i can copy-paste
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      # locations        = ["US", "CA", "GB", "DE", "FR", "IT", "ES", "IE", "NL", "SE", "CH"]
      locations = ["PT"] # just Portugal to be safe...
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

# get the CloudFront distribution domain name
output "cloudfront_distribution_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
