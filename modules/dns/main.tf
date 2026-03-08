###############################################################################
# DNS Module – Main
# MIT 565 Azure Lab
#
# Concepts demonstrated:
#   - DNS zone hosting (like running a DNS server)
#   - A records (hostname → IPv4 address)
#   - AAAA records would map to IPv6 (not used here)
#   - Private DNS zones (internal resolution, no public exposure)
#   - DNS auto-registration (VMs automatically get DNS entries)
#   - Name resolution across VNets (linked VNets can resolve names)
#
# In class you learn:
#   nslookup server1.mit565.local
#   → resolves to 10.10.0.10
#
# In Azure:
#   Private DNS zone "mit565.local" with A record "server1" → 10.10.0.10
#   VNets linked to zone can resolve these names automatically
###############################################################################

resource "azurerm_private_dns_zone" "zone" {
  name                = var.dns_zone_name
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Link each VNet to the private DNS zone for name resolution
# This is like configuring DNS forwarders on each network's DNS settings
resource "azurerm_private_dns_zone_virtual_network_link" "links" {
  for_each              = var.vnet_links
  name                  = "dnslink-${each.key}"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.zone.name
  virtual_network_id    = each.value
  registration_enabled  = true
}

# Create A records (hostname → IP mapping)
# Like: nslookup dns-server.mit565.local → 10.10.2.10
resource "azurerm_private_dns_a_record" "records" {
  for_each            = var.dns_records
  name                = each.key
  zone_name           = azurerm_private_dns_zone.zone.name
  resource_group_name = var.resource_group_name
  ttl                 = 300
  records             = [each.value]
}
