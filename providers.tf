terraform {

  # terraform version
  required_version = ">=1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.51.0"
    }
  }
}

# Configuration options
provider "aws" {
  region = var.my_region
}
