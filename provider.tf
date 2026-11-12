terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  # HCP Terraform stores a separate state per client.
  # GitHub Actions supplies `organization` to `terraform init`.
  # Create workspaces such as client-acme-prod in LOCAL execution mode.
  backend "remote" {
    hostname = "app.terraform.io"

    workspaces {
      prefix = "client-"
    }
  }
}

provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
