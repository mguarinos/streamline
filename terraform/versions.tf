terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Placeholder backend — developer workflow:
  #   1. Run scripts/bootstrap.sh  (creates the S3 state bucket)
  #   2. terraform init -backend-config=terraform/backend.hcl
  #
  # Locking uses Terraform 1.10+ native S3 locking (use_lockfile = true).
  # No DynamoDB table required.
  backend "s3" {
    bucket       = "PLACEHOLDER-terraform-state"
    key          = "streamline/terraform.tfstate"
    region       = "PLACEHOLDER"
    encrypt      = true
    use_lockfile = true
  }
}
