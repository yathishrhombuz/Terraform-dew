# Creates one client's Azure footprint:
#   - a networking resource group with a VNet, two subnets, and an NSG
#   - a web resource group with one Linux App Service plan
#   - two Linux Web Apps on that plan: React (frontend) and FastAPI (API)
#
# The web apps stay on public App Service hostnames. The VNet is created
# but is not attached to either app. Making the API private needs extra
# design (VNet integration or private endpoints, DNS, and how the browser
# reaches the API).

# Tags applied to every resource so you can see which client owns it
# and that Terraform manages it.
locals {
  common_tags = {
    client     = var.client_code
    managed_by = "terraform"
  }
}

# Container for the VNet. Kept separate from the web apps so networking
# and compute can be permissioned or deleted independently.
resource "azurerm_resource_group" "rg" {
  name     = "rg-${var.client_code}-network"
  location = var.location
  tags     = local.common_tags
}

# Private IP space for this client: 10.0.0.0/16 (65,536 addresses).
# Nothing is placed in it yet; the web apps do not use these addresses.
resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${var.client_code}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.common_tags
}

# First slice of the VNet. The name "public" is only a label.
# Azure does not expose this subnet to the internet by itself.
resource "azurerm_subnet" "public" {
  name                 = "public-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Second slice, intended for private workloads later.
# The web apps are not deployed into this subnet.
resource "azurerm_subnet" "private" {
  name                 = "private-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Firewall rules for the private subnet. No custom rules are defined,
# so Azure's built-in NSG defaults apply. Attached only to private-subnet.
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

# Container for the App Service plan and both web apps.
resource "azurerm_resource_group" "web" {
  name     = "rg-${var.client_code}-webapp"
  location = var.location
  tags     = local.common_tags
}

# The compute both sites share. You pay for this plan, not per web app.
# Linux + the SKU from variables (B1 unless overridden).
resource "azurerm_service_plan" "plan" {
  name                = "asp-${var.client_code}"
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  os_type             = "Linux"
  sku_name            = var.app_service_sku_name
  tags                = local.common_tags
}

# Frontend. CI builds the React app and uploads only the compiled files
# (the dist/ folder). This resource does not build the app.
resource "azurerm_linux_web_app" "react" {
  name                = var.react_webapp_name
  location            = azurerm_resource_group.web.location
  resource_group_name = azurerm_resource_group.web.name
  service_plan_id     = azurerm_service_plan.plan.id
  https_only          = true

  site_config {
    # Keep the process running so the first request is not a cold start.
    always_on           = true
    minimum_tls_version = "1.2"
    # No FTP. Deployments go through the GitHub workflow, not file transfer.
    ftps_state          = "Disabled"

    application_stack {
      node_version = "22-lts"
    }

    # pm2 serves the static files already sitting in wwwroot and
    # sends unknown paths back to index.html so client-side routes work.
    app_command_line = "pm2 serve /home/site/wwwroot --no-daemon --spa"
  }

  app_settings = {
    # The ZIP already contains built files, so Azure should not run npm.
    SCM_DO_BUILD_DURING_DEPLOYMENT = "false"
  }

  tags = merge(local.common_tags, { component = "react" })
}

# API. CI uploads the Python source. Azure then installs
# requirements.txt because the build setting below is true.
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

    # Starts the API. Expects backend/main.py to define `app = FastAPI()`
    # and requirements.txt to include uvicorn. Change this if the
    # module or variable name is different.
    app_command_line = "python -m uvicorn main:app --host 0.0.0.0 --port 8000"
  }

  app_settings = {
    # Ask App Service to pip-install requirements.txt on ZIP deploy.
    SCM_DO_BUILD_DURING_DEPLOYMENT = "true"
    # The React site's public URL. The FastAPI code must read this and
    # pass it to CORSMiddleware. Setting it here does not enable CORS.
    FRONTEND_ORIGIN = "https://${azurerm_linux_web_app.react.default_hostname}"
  }

  tags = merge(local.common_tags, { component = "fastapi" })
}
