terraform {
  required_version = ">= 1.9.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }

  # S3 Backend for Remote State (REQUIRED for CI/CD)
  #
  # To enable remote state:
  # 1. First, apply with enable_terraform_state_resources=true to create the bucket/table
  # 2. Uncomment the backend block below and fill in your bucket name
  # 3. Run: terraform init -migrate-state
  #
  # backend "s3" {
  #   bucket         = "YOUR-STATE-BUCKET-NAME"
  #   key            = "pkm-agent/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "pkm-agent-terraform-state-lock"
  # }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.tags
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
