# Existing architecture preserved: one networking RG, one web RG,
# a VNet with two subnets and an NSG, and two Linux Web Apps on one plan.
# IMPORTANT: These subnets are not connected to either Web App; App Service
# endpoints remain public. Private access requires additional Azure design.

locals {
  common_tags = {
    client     = var.client_code
    managed_by = "terraform"
  }
}

# 1. Networking resource group
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.client_code}-network"
  location = var.location
  tags     = local.common_tags
}

# 2. VNet
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.client_code}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# 3. Subnet named public (the name alone does not make it public)
resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# 4. Private workload subnet (not wired to the Web Apps)
resource "azurerm_subnet" "private" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# 5. NSG and subnet association (default NSG rules only)
resource "azurerm_network_security_group" "private_nsg" {
  name                = "nsg-${var.client_code}-private"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = local.common_tags
}

resource "azurerm_subnet_network_security_group_association" "private" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}

# 6. Web applications resource group
resource "azurerm_resource_group" "web" {
  name     = "rg-${var.client_code}-webapp"
  location = var.location
  tags     = local.common_tags
}

# 7. Shared Linux App Service plan: B1 default (billable)
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.client_code}"
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku_name
  tags                = local.common_tags
}

# 8. React SPA: CI deploys only the compiled dist/ contents
resource "azurerm_linux_web_app" "react" {
  name                = var.react_webapp_name
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  site_config {
    always_on           = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    application_stack {
      node_version = "22-lts"
    }

    # Azure's PM2 serves the static React bundle and handles SPA routes.
    app_command_line = "pm2 serve /home/site/wwwroot --no-daemon --spa"
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "false"
  }

  tags = merge(local.common_tags, { component = "react" })
}

# 9. FastAPI: Azure builds requirements.txt after ZIP deployment
resource "azurerm_linux_web_app" "fastapi" {
  name                = var.fastapi_webapp_name
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  site_config {
    always_on           = true
    minimum_tls_version = "1.2"
    ftps_state          = "Disabled"

    application_stack {
      python_version = "3.12"
    }

    # Assumes backend/main.py defines `app = FastAPI()` and uvicorn is
    # listed in requirements.txt. Python 3.12 needs a startup command.
    app_command_line = "python -m uvicorn main:app --host 0.0.0.0 --port 8000"
  }

  app_settings = {
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    # Only useful if your API reads it and configures CORS appropriately.
    FRONTEND_ORIGIN = "https://${azurerm_linux_web_app.react.default_hostname}"
  }

  tags = merge(local.common_tags, { component = "fastapi" })
}
