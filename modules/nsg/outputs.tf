output "hr_nsg_id" {
  value = azurerm_network_security_group.hr.id
}

output "finance_nsg_id" {
  value = azurerm_network_security_group.finance.id
}

output "it_nsg_id" {
  value = azurerm_network_security_group.it.id
}
