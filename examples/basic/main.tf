terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

variable "region" {
  description = "AWS region to deploy the example role into."
  type        = string
  default     = "us-east-1"
}

provider "aws" {
  region = var.region
}

data "aws_iam_policy_document" "assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

module "iam" {
  source = "../.."

  name               = "example-ec2-role"
  assume_role_policy = data.aws_iam_policy_document.assume.json

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]

  tags = {
    Environment = "sandbox"
    ManagedBy   = "terraform"
  }
}

output "role_arn" {
  value = module.iam.arn
}
