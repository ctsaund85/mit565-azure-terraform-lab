###############################################################################
# NSG Module – Main
# MIT 565 Azure Lab
#
# Concepts demonstrated:
#   - Standard ACLs (filter by source only)
#   - Extended ACLs (filter by source, destination, port, protocol)
#   - ACL placement logic (applied to subnet = interface-level ACL)
#   - Deny-all implicit rule (Azure NSGs have a default deny at priority 65500)
#   - Permit/Deny rules with priority ordering
#
# Each department gets its own NSG with rules that mirror ACL behavior:
#   - HR: Can reach Finance (inter-department), no RDP to servers
#   - Finance: Isolated, only outbound HTTP/DNS allowed
#   - IT: Full access (admin VLAN), can RDP everywhere
###############################################################################

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  HR DEPARTMENT NSG – Like a standard + extended ACL on an interface    ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_network_security_group" "hr" {
  name                = "nsg-hr-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # ── Inbound Rules ────────────────────────────────────────────────────────

  # Allow ICMP (ping) from IT subnet – like: permit icmp host IT any
  security_rule {
    name                       = "Allow-ICMP-From-IT"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.it_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow RDP from IT only – like: permit tcp host IT any eq 3389
  security_rule {
    name                       = "Allow-RDP-From-IT"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.it_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow inbound from Finance (inter-department communication)
  security_rule {
    name                       = "Allow-From-Finance"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.finance_subnet_prefix
    destination_address_prefix = "*"
  }

  # Deny RDP from Finance – like: deny tcp host Finance any eq 3389
  security_rule {
    name                       = "Deny-RDP-From-Finance"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.finance_subnet_prefix
    destination_address_prefix = "*"
  }

  # ── Outbound Rules ──────────────────────────────────────────────────────

  # Allow DNS outbound – like: permit udp any any eq 53
  security_rule {
    name                       = "Allow-DNS-Out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP/HTTPS outbound
  security_rule {
    name                       = "Allow-Web-Out"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate HR NSG to HR subnet (like applying ACL to an interface)
resource "azurerm_subnet_network_security_group_association" "hr" {
  subnet_id                 = var.hr_subnet_id
  network_security_group_id = azurerm_network_security_group.hr.id
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  FINANCE DEPARTMENT NSG – Restricted / isolated department             ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_network_security_group" "finance" {
  name                = "nsg-finance-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow ICMP from IT
  security_rule {
    name                       = "Allow-ICMP-From-IT"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Icmp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = var.it_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow RDP from IT only
  security_rule {
    name                       = "Allow-RDP-From-IT"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.it_subnet_prefix
    destination_address_prefix = "*"
  }

  # Deny all other inbound from HR and other departments
  security_rule {
    name                       = "Deny-RDP-From-HR"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = var.hr_subnet_prefix
    destination_address_prefix = "*"
  }

  # Allow DNS outbound
  security_rule {
    name                       = "Allow-DNS-Out"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "53"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP/HTTPS outbound
  security_rule {
    name                       = "Allow-Web-Out"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "finance" {
  subnet_id                 = var.finance_subnet_id
  network_security_group_id = azurerm_network_security_group.finance.id
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  IT DEPARTMENT NSG – Full access (admin VLAN)                          ║
# ╠═══════════════════════════════════════════════════════════════════════════╣

resource "azurerm_network_security_group" "it" {
  name                = "nsg-it-${var.branch_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  tags                = var.tags

  # Allow all inbound from VNet (IT has admin access)
  security_rule {
    name                       = "Allow-All-VNet-Inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "*"
  }

  # Allow all outbound (IT can reach everything)
  security_rule {
    name                       = "Allow-All-Outbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "it" {
  subnet_id                 = var.it_subnet_id
  network_security_group_id = azurerm_network_security_group.it.id
}
