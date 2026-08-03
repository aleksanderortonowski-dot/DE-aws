terraform {
  required_version = ">= 1.7.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }


  backend "s3" {
    bucket         = "kurs-de-aleksander-ortonowski"
    key            = "ecommerce/dev/terraform.tfstate"
    region         = "eu-north-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
    profile        = "ecommerce-dev"
  }
}

provider "aws" {

  region = var.aws_region
  profile = "ecommerce-dev"
  default_tags {
    tags = local.common_tags
  }
}
