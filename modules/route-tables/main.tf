###############################################################################
# Route Tables Module – Main
# MIT 565 Azure Lab
#
# Concepts demonstrated:
#   - Static routing (User-Defined Routes / UDRs)
#   - Null routes (blackhole) – dropping traffic at Layer 3
#   - Routing table entries (destination prefix → next hop)
#   - Administrative distance concept (UDR overrides system routes)
#   - Defense in depth (routing + ACLs = two layers of security)
#   - BGP route propagation (dynamic routes from VPN gateway)
#
# In a physical network:
#   ip route 10.x.x.0 255.255.255.0 Null0  ← blackhole route (drop traffic)
#   ip route 0.0.0.0 0.0.0.0 10.x.x.1      ← default route to gateway
#
# In Azure:
#   Route tables can override system routes with custom next-hops.
#   next_hop_type = "None" = null route = silently drop matching packets.
#   This creates DEFENSE IN DEPTH with NSGs:
#     Layer 3 (routing): Null route drops HR↔Finance traffic
#     Layer 4 (ACLs):    NSG denies HR↔Finance RDP
#   Even if one layer is misconfigured, the other still blocks traffic.
#
# NOTE: BGP route propagation is ENABLED so VPN gateway learned routes
# (cross-branch prefixes) reach the spoke subnets. Disabling it would
# break inter-branch connectivity — like removing OSPF/EIGRP from an
# interface while keeping only static routes.
###############################################################################

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  HR DEPARTMENT ROUTE TABLE                                              ║
# ║  Null route to Finance = blackhole (like ip route 10.x.x.0 Null0)      ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_route_table" "hr" {
  name                = "rt-hr-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Enable BGP route propagation so VPN gateway routes reach this subnet
  # Like allowing OSPF/EIGRP learned routes on an interface
  bgp_route_propagation_enabled = true
}

# Null route: Drop all traffic from HR → Finance subnet
# Cisco equivalent: ip route <finance_prefix> 255.255.255.0 Null0
# This blocks at the ROUTING layer — packets never even reach the NSG
resource "azurerm_route" "hr_block_finance" {
  name                = "blackhole-to-finance"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.hr.name
  address_prefix      = var.finance_subnet_prefix
  next_hop_type       = "None"
}

resource "azurerm_subnet_route_table_association" "hr" {
  subnet_id      = var.hr_subnet_id
  route_table_id = azurerm_route_table.hr.id
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  FINANCE DEPARTMENT ROUTE TABLE                                         ║
# ║  Null route to HR = blackhole (like ip route 10.x.x.0 Null0)           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_route_table" "finance" {
  name                = "rt-finance-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  bgp_route_propagation_enabled = true
}

# Null route: Drop all traffic from Finance → HR subnet
# Cisco equivalent: ip route <hr_prefix> 255.255.255.0 Null0
resource "azurerm_route" "finance_block_hr" {
  name                = "blackhole-to-hr"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.finance.name
  address_prefix      = var.hr_subnet_prefix
  next_hop_type       = "None"
}

resource "azurerm_subnet_route_table_association" "finance" {
  subnet_id      = var.finance_subnet_id
  route_table_id = azurerm_route_table.finance.id
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  IT DEPARTMENT ROUTE TABLE                                              ║
# ║  No blocking routes – IT can reach all subnets (admin access)           ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_route_table" "it" {
  name                = "rt-it-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  bgp_route_propagation_enabled = true
}

resource "azurerm_subnet_route_table_association" "it" {
  subnet_id      = var.it_subnet_id
  route_table_id = azurerm_route_table.it.id
}
