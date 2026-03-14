###############################################################################
# Hub-Spoke VNet Module – Main
# MIT 565 Azure Lab
#
# Concepts demonstrated:
#   - Subnetting & CIDR (address spaces, subnet prefixes)
#   - VLANs → Subnets (HR, Finance, IT department isolation)
#   - Switching/Peering (Hub↔Spoke VNet peering ≈ trunk links)
#   - Routing (VPN Gateway for inter-branch connectivity)
#   - NAT Gateway (outbound internet via SNAT, like ip nat inside/outside)
#   - Bastion (secure management access without public IPs)
###############################################################################

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  HUB VNET – Core network services (Gateway, Bastion, NAT Gateway)      ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_virtual_network" "hub" {
  name                = "hub-vnet-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  address_space       = var.hub_address_space
  tags                = var.tags
}

# GatewaySubnet – required name for VPN/ExpressRoute gateways
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.gateway_subnet_prefix]
}

# AzureBastionSubnet – required name for Bastion host
resource "azurerm_subnet" "bastion" {
  count                = var.bastion_enabled ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = [var.bastion_subnet_prefix]
}



# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  SPOKE VNET – Department subnets (HR, Finance, IT = VLANs)            ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_virtual_network" "spoke" {
  name                = "spoke-vnet-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  address_space       = var.spoke_address_space
  tags                = var.tags
}

# HR Department Subnet (VLAN 10 equivalent)
resource "azurerm_subnet" "hr" {
  name                 = "snet-hr-${var.branch_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.hr_subnet_prefix]
}

# Finance Department Subnet (VLAN 20 equivalent)
resource "azurerm_subnet" "finance" {
  name                 = "snet-finance-${var.branch_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.finance_subnet_prefix]
}

# IT Department Subnet (VLAN 30 equivalent)
resource "azurerm_subnet" "it" {
  name                 = "snet-it-${var.branch_name}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = [var.it_subnet_prefix]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  VNET PEERING – Hub ↔ Spoke (like a trunk link between switches)          ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "hub-to-spoke-${var.branch_name}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
  allow_forwarded_traffic   = true
  allow_gateway_transit     = var.vpn_gateway_enabled

  depends_on = [azurerm_virtual_network_gateway.vpn_gateway]
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "spoke-to-hub-${var.branch_name}"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
  allow_forwarded_traffic   = true
  use_remote_gateways       = var.vpn_gateway_enabled

  depends_on = [azurerm_virtual_network_gateway.vpn_gateway]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  AZURE BASTION – Secure RDP/SSH without public IPs on VMs                 ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_public_ip" "bastion" {
  count               = var.bastion_enabled ? 1 : 0
  name                = "pip-bastion-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_bastion_host" "bastion" {
  count               = var.bastion_enabled ? 1 : 0
  name                = "bastion-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags

  tunneling_enabled = true

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.bastion[0].id
    public_ip_address_id = azurerm_public_ip.bastion[0].id
  }
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  NAT GATEWAY – Outbound Internet Access (SNAT)                            ║
# ║  Demonstrates: NAT (like Cisco ip nat inside/outside)                     ║
# ║  All spoke subnet traffic to the internet is SNATed through this gateway  ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_public_ip" "nat_gateway" {
  count               = var.nat_gateway_enabled ? 1 : 0
  name                = "pip-natgw-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway" "nat_gateway" {
  count               = var.nat_gateway_enabled ? 1 : 0
  name                = "natgw-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
  tags                = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "nat_gateway" {
  count                = var.nat_gateway_enabled ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.nat_gateway[0].id
  public_ip_address_id = azurerm_public_ip.nat_gateway[0].id
}

# Associate NAT Gateway with each spoke subnet for outbound internet
# Like configuring "ip nat inside" on each VLAN interface
resource "azurerm_subnet_nat_gateway_association" "hr" {
  count          = var.nat_gateway_enabled ? 1 : 0
  subnet_id      = azurerm_subnet.hr.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
}

resource "azurerm_subnet_nat_gateway_association" "finance" {
  count          = var.nat_gateway_enabled ? 1 : 0
  subnet_id      = azurerm_subnet.finance.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
}

resource "azurerm_subnet_nat_gateway_association" "it" {
  count          = var.nat_gateway_enabled ? 1 : 0
  subnet_id      = azurerm_subnet.it.id
  nat_gateway_id = azurerm_nat_gateway.nat_gateway[0].id
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  VPN GATEWAY – Inter-branch connectivity (like WAN links / OSPF/BGP)      ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_public_ip" "vpn_gateway" {
  count               = var.vpn_gateway_enabled ? 1 : 0
  name                = "pip-vpngw-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = var.tags
}

resource "azurerm_virtual_network_gateway" "vpn_gateway" {
  count               = var.vpn_gateway_enabled ? 1 : 0
  name                = "vpngw-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  type                = "Vpn"
  vpn_type            = "RouteBased"
  sku                 = "VpnGw1"
  active_active       = false
  bgp_enabled         = true
  tags                = var.tags

  # Serialize VPN gateway creation — Azure fails when two gateways
  # are provisioned simultaneously in the same subscription.
  # The tautology below is intentional: referencing the variable forces
  # Terraform to evaluate it, creating an implicit dependency on the
  # other gateway's completion without using depends_on (which would
  # force unnecessary recreation on changes).
  lifecycle {
    precondition {
      condition     = var.vpn_gateway_depends_on_id != null || var.vpn_gateway_depends_on_id == null
      error_message = "Waiting for dependency gateway to finish provisioning."
    }
  }

  bgp_settings {
    asn = var.bgp_asn
  }

  ip_configuration {
    name                          = "vnetGatewayConfig"
    public_ip_address_id          = azurerm_public_ip.vpn_gateway[0].id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.gateway.id
  }

  timeouts {
    create = "60m"
    update = "60m"
    delete = "60m"
  }

  # Pre-delete the VPN gateway via Azure CLI before Terraform's own delete.
  # This handles gateways stuck in "Failed" state which block PIP/subnet deletion.
  provisioner "local-exec" {
    when    = destroy
    command = <<-EOT
      echo "Pre-deleting VPN gateway ${self.name} via Azure CLI for clean destroy..."
      az network vnet-gateway delete \
        --name "${self.name}" \
        --resource-group "${self.resource_group_name}" 2>/dev/null || true
      echo "VPN gateway ${self.name} pre-deletion complete"
    EOT
    on_failure = continue
  }
}