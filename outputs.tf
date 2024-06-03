output "s3_bucket_name_ouput" {
  value = aws_s3_bucket.web_app_bucket.id
}

output "web_app_url_output" {
  value = aws_cloudfront_distribution.web_app_distribution.domain_name
}

output "domain_name_output" {
  value = var.domain_name
}

