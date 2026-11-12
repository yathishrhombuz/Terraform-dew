# Pins the Terraform and Azure provider versions, and tells Terraform
# where to keep state.
#
# State is stored in HCP Terraform (app.terraform.io), one workspace per
# client. Workspace names look like client-acme-prod. GitHub Actions
# supplies the organization name when it runs `terraform init`, and it
# runs Terraform itself (Local execution mode). HCP Terraform only stores
# the state file so two clients never share one state.
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }

  backend "remote" {
    hostname = "app.terraform.io"

    # "client-" is a prefix. The rest of the name (for example acme-prod)
    # is chosen per client with the TF_WORKSPACE environment variable.
    workspaces {
      prefix = "client-"
    }
  }
}

# Talks to the Azure subscription this client authorized.
# subscription_id comes from TF_VAR_subscription_id (the service principal
# JSON in GitHub), not from a committed file.
provider "azurerm" {
  features {}

  subscription_id = var.subscription_id
}
