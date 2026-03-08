output "hr_route_table_id" {
  value = azurerm_route_table.hr.id
}

output "finance_route_table_id" {
  value = azurerm_route_table.finance.id
}

output "it_route_table_id" {
  value = azurerm_route_table.it.id
}
