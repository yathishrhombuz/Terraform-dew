# Values that change from one client to the next.
# In GitHub Actions they arrive as TF_VAR_* from that client's Environment.
# For a local trial, copy terraform.tfvars.example to terraform.tfvars.
# Never commit a real terraform.tfvars file.

# Azure subscription this stack is allowed to create resources in.
variable "subscription_id" {
  description = "Azure subscription ID authorized for this client"
  type        = string
}

# Region for every resource in this stack (for example eastus).
variable "location" {
  description = "Azure region for the client's resources"
  type        = string
}

# Short name used in resource group, VNet, and App Service plan names.
# Example: "acme" becomes rg-acme-webapp and asp-acme.
# Two environments in the same subscription need different codes
# (acmeprod and acmedev) or their resource group names will collide.
variable "client_code" {
  description = "Unique client/environment identifier, 3-20 lowercase characters"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.client_code))
    error_message = "Use 3-20 lowercase letters, numbers or hyphens; start/end with a letter or number."
  }
}

# App Service names are global across all of Azure, so these cannot
# be guessed from client_code alone. Pick something unique per client.
variable "react_webapp_name" {
  description = "Globally unique Azure App Service name for the React frontend"
  type        = string
}

variable "fastapi_webapp_name" {
  description = "Globally unique Azure App Service name for the FastAPI backend"
  type        = string
}

# Size of the shared Linux plan that runs both web apps.
# B1 is the smallest paid tier that keeps apps always on. It is billed
# even when nobody is using the site.
variable "app_service_sku_name" {
  description = "Linux App Service plan SKU. B1 is billable and hosts both apps."
  type        = string
  default     = "B1"
}
