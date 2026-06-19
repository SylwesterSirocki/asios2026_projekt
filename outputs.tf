output "frontend_public_ip" {
  value = azurerm_public_ip.frontend_public_ip.ip_address
}

output "frontend_private_ip" {
  value = azurerm_network_interface.frontend_nic.private_ip_address
}

output "backend_private_ip" {
  value = azurerm_network_interface.backend_nic.private_ip_address
}