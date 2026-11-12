variable "subscription_id" {
  description = "Azure subscription ID authorized for this client"
  type        = string
}

variable "location" {
  description = "Azure region for the client's resources"
  type        = string
}

variable "client_code" {
  description = "Unique client/environment identifier, 3-20 lowercase characters"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,18}[a-z0-9]$", var.client_code))
    error_message = "Use 3-20 lowercase letters, numbers or hyphens; start/end with a letter or number."
  }
}

variable "react_webapp_name" {
  description = "Globally unique Azure App Service name for the React frontend"
  type        = string
}

variable "fastapi_webapp_name" {
  description = "Globally unique Azure App Service name for the FastAPI backend"
  type        = string
}

variable "app_service_sku_name" {
  description = "Linux App Service plan SKU. B1 is billable and hosts both apps."
  type        = string
  default     = "B1"
}
