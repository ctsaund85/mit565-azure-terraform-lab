output "hub_vnet_id" {
  value = azurerm_virtual_network.hub.id
}

output "hub_vnet_name" {
  value = azurerm_virtual_network.hub.name
}

output "spoke_vnet_id" {
  value = azurerm_virtual_network.spoke.id
}

output "spoke_vnet_name" {
  value = azurerm_virtual_network.spoke.name
}

output "hr_subnet_id" {
  value = azurerm_subnet.hr.id
}

output "finance_subnet_id" {
  value = azurerm_subnet.finance.id
}

output "it_subnet_id" {
  value = azurerm_subnet.it.id
}

output "gateway_subnet_id" {
  value = azurerm_subnet.gateway.id
}

output "vpn_gateway_id" {
  value = var.vpn_gateway_enabled ? azurerm_virtual_network_gateway.vpn_gateway[0].id : null
}

output "vpn_gateway_bgp_settings" {
  value = var.vpn_gateway_enabled ? azurerm_virtual_network_gateway.vpn_gateway[0].bgp_settings : null
}

output "nat_gateway_public_ip" {
  description = "Public IP of the NAT Gateway (outbound SNAT address)"
  value       = var.nat_gateway_enabled ? azurerm_public_ip.nat_gateway[0].ip_address : null
}