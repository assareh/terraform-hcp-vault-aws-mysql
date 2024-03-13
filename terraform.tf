terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.8"
    }
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.25"
    }
  }
}