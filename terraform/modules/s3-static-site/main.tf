variable "bucket_name" {
  description = "The name of the S3 bucket."
  type        = string
}

resource "aws_s3_bucket" "site" {
  bucket = var.bucket_name
  force_destroy = true
}

resource "aws_s3_bucket_website_configuration" "site" {
  bucket = aws_s3_bucket.site.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "index.html"
  }
}

resource "aws_s3_bucket_policy" "site" {
  bucket = aws_s3_bucket.site.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Sid       = "PublicReadGetObject",
        Effect    = "Allow",
        Principal = "*",
        Action    = "s3:GetObject",
        Resource  = "${aws_s3_bucket.site.arn}/*"
      }
    ]
  })
}

output "website_endpoint" {
  description = "The S3 bucket website endpoint."
  value       = aws_s3_bucket_website_configuration.site.website_endpoint
}
