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

output "react_webapp_url" {
  value = "https://${azurerm_linux_web_app.react.default_hostname}"
}

output "fastapi_webapp_url" {
  value = "https://${azurerm_linux_web_app.fastapi.default_hostname}"
}

output "network_resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "virtual_network_id" {
  value = azurerm_virtual_network.vnet.id
}

output "public_subnet_id" {
  value = azurerm_subnet.public.id
}

output "private_subnet_id" {
  value = azurerm_subnet.private.id
}
