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

provider "aws" {
  region = var.my_region
}

# To work with cloudfront, apparently you *must* use the "us-east-1"
provider "aws" {
  alias  = "cloudfront"
  region = "us-east-1"
}
