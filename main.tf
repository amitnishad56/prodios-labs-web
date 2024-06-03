provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
}

resource "aws_s3_bucket" "web_app_bucket" {
  bucket = var.s3_bucket_name
}

resource "aws_s3_bucket_versioning" "web_app_bucket_versioning" {
  bucket = aws_s3_bucket.web_app_bucket.bucket
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "web_app_bucket_lifecycle" {
  bucket = aws_s3_bucket.web_app_bucket.bucket

  rule {
    id     = "log"
    status = "Enabled"

    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }

    expiration {
      days = 365
    }
  }
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_security_group" "web_app_sg" {
  name        = "web_app_sg"
  description = "Allow HTTP and SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web_app" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  security_groups = [aws_security_group.web_app_sg.name]
  user_data     = <<-EOF
                  #!/bin/bash
                  yum update -y
                  amazon-linux-extras install docker -y
                  service docker start
                  usermod -a -G docker ec2-user
                  docker run -d -p 80:80 \
                  -e AWS_ACCESS_KEY_ID=${var.aws_access_key_id} \
                  -e AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key} \
                  -e S3_BUCKET_NAME=${var.s3_bucket_name} \
                  -e AWS_REGION=${var.aws_region} \
                  nginx
                  EOF

  tags = {
    Name = "web_app_instance"
  }
}

resource "aws_elb" "web_app_elb" {
  name               = "web-app-elb"
  availability_zones = ["${var.aws_region}a"]

  listener {
    instance_port     = 80
    instance_protocol = "HTTP"
    lb_port           = 80
    lb_protocol       = "HTTP"
  }

  instances = [aws_instance.web_app.id]
}

resource "aws_launch_configuration" "web_app_lc" {
  name          = "web_app_lc"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.instance_type
  user_data     = <<-EOF
                  #!/bin/bash
                  yum update -y
                  amazon-linux-extras install docker -y
                  service docker start
                  usermod -a -G docker ec2-user
                  docker run -d -p 80:80 \
                  -e AWS_ACCESS_KEY_ID=${var.aws_access_key_id} \
                  -e AWS_SECRET_ACCESS_KEY=${var.aws_secret_access_key} \
                  -e S3_BUCKET_NAME=${var.s3_bucket_name} \
                  -e AWS_REGION=${var.aws_region} \
                  nginx
                  EOF
}

resource "aws_autoscaling_group" "web_app_asg" {
  launch_configuration = aws_launch_configuration.web_app_lc.id
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  vpc_zone_identifier  = [var.subnet_id]

  tag {
    key                 = "Name"
    value               = "web_app_instance"
    propagate_at_launch = true
  }
}

resource "aws_cloudfront_distribution" "web_app_distribution" {
  origin {
    domain_name = aws_elb.web_app_elb.dns_name
    origin_id   = "web_app_elb"

    custom_origin_config {
      http_port              = 80
      https_port             = 80
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]  # Specify the desired SSL/TLS protocols
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "web_app_elb"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_route53_zone" "web_app_zone" {
  name = var.domain_name
}

resource "aws_route53_record" "web_app_record" {
  zone_id = aws_route53_zone.web_app_zone.zone_id
  name    = var.domain_name
  type    = "A"
  alias {
    name                   = aws_cloudfront_distribution.web_app_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.web_app_distribution.hosted_zone_id
    evaluate_target_health = false
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.web_app_bucket.id
}

output "web_app_url" {
  value = aws_cloudfront_distribution.web_app_distribution.domain_name
}

output "domain_name" {
  value = var.domain_name
}

