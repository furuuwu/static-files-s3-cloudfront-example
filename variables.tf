variable "my_region" {
  type    = string
  default = "eu-west-1"
}

variable "s3_bucket_name" {
  description = "The name of the S3 bucket"
  type        = string
  default     = "just-a-bucket"
}

variable "file_path" {
  type    = string
  default = "/" # cange if you want to put it in some "folder"
}

variable "my_ip" {
  type        = string
  description = "My IP"
}
