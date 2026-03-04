terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "adventureconnect-terraform-state-bucket"
    key            = "adventureconnect-contact-system/terraform.tfstate"
    region         = "eu-central-1"
    dynamodb_table = "adventureconnect-terraform-locks"
  }
}

provider "aws" {
  region = "eu-central-1"
}
