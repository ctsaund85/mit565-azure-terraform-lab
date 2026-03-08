output "vm_id" {
  value = azurerm_windows_virtual_machine.client.id
}

output "vm_name" {
  value = azurerm_windows_virtual_machine.client.name
}

output "private_ip_address" {
  value = azurerm_network_interface.nic.private_ip_address
}

output "nic_id" {
  value = azurerm_network_interface.nic.id
}