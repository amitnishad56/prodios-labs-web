variable "aws_region" {
  description = "The AWS region to deploy resources in"
  default     = "ap-south-1"
}

variable "instance_type" {
  description = "The EC2 instance type"
  default     = "t2.micro"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
}

variable "domain_name" {
  description = "The domain name for the web application"
  type        = string
}

variable "aws_access_key_id" {
  description = "AWS Access Key ID"
  type        = string
}

variable "aws_secret_access_key" {
  description = "AWS Secret Access Key"
  type        = string
}

variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "subnet_id" {
  description = "The ID of the subnet"
  type        = string
}

