# Printed after apply, and read by the GitHub workflow so it knows
# which resource group and web apps to deploy the code into.

# Resource group that holds the App Service plan and both web apps.
output "resource_group_name" {
  description = "Resource group containing the Linux App Service plan and both Web Apps"
  value       = azurerm_resource_group.web.name
}

output "react_webapp_name" {
  description = "Name of the provisioned React Web App"
  value       = azurerm_linux_web_app.react.name
}

output "fastapi_webapp_name" {
  description = "Name of the provisioned FastAPI Web App"
  value       = azurerm_linux_web_app.fastapi.name
}

# Public HTTPS addresses Azure assigns. The React build is pointed at
# the FastAPI URL so the browser knows where to call the API.
output "react_webapp_url" {
  description = "Public HTTPS URL of the React Web App"
  value       = "https://${azurerm_linux_web_app.react.default_hostname}"
}

output "fastapi_webapp_url" {
  description = "Public HTTPS URL of the FastAPI Web App"
  value       = "https://${azurerm_linux_web_app.fastapi.default_hostname}"
}

# Networking outputs are for later wiring (VNet integration, private
# endpoints). Nothing in this stack attaches the web apps to these subnets.
output "network_resource_group_name" {
  description = "Resource group that holds the VNet, subnets, and NSG"
  value       = azurerm_resource_group.rg.name
}

output "virtual_network_id" {
  description = "ID of the client virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "public_subnet_id" {
  description = "ID of public-subnet (10.0.1.0/24). Name does not make it public."
  value       = azurerm_subnet.public.id
}

output "private_subnet_id" {
  description = "ID of private-subnet (10.0.2.0/24). Not connected to the web apps."
  value       = azurerm_subnet.private.id
}
