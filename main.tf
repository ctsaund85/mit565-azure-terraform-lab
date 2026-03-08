###############################################################################
# MIT 565 – Internetworking Azure Lab
# Root Module – main.tf
#
# This lab deploys a complete Azure network environment that demonstrates
# every core concept from MIT 565, mapped to Azure equivalents:
#
# ┌─────────────────────────┬──────────────────────────────────────────────┐
# │ MIT 565 Concept         │ Azure Implementation                         │
# ├─────────────────────────┼──────────────────────────────────────────────┤
# │ VLANs                   │ Subnets (HR, Finance, IT per branch)         │
# │ Trunk Links             │ VNet Peering (Hub↔Spoke)                     │
# │ IP Addressing/CIDR      │ VNet address spaces, subnet prefixes         │
# │ Default Gateway         │ Azure virtual router                         │
# │ Static Routing          │ User-Defined Routes (UDRs)                   │
# │ Dynamic Routing (BGP)   │ VPN Gateway with BGP enabled                 │
# │ ACLs (Standard/Extended)│ Network Security Groups (NSGs)               │
# │ NAT                     │ NAT Gateway (outbound SNAT)                  │
# │ DNS                     │ Azure Private DNS Zones + Windows DNS        │
# │ ARP / MAC               │ VM NICs with virtual MACs                    │
# │ WAN Links               │ VPN Gateway site-to-site connections         │
# │ Bastion/Management      │ Azure Bastion (secure RDP without pub IPs)   │
# └─────────────────────────┴──────────────────────────────────────────────┘
#
# DEMO PHASES – Toggle in terraform.tfvars for incremental deployment:
#   Phase 1: Core Networking (always on) – VNets, Subnets, Peering, Bastion
#   Phase 2: NAT Gateway – outbound internet via SNAT
#   Phase 3: NSGs – Access Control Lists
#   Phase 4: Route Tables – static routing / UDRs
#   Phase 5: DNS – Azure DNS zone + Windows DNS server
#   Phase 6: Client VMs – department workstations
#   Phase 7: VPN Gateway – WAN links + BGP
#   Phase 8: Web Server – IIS + documentation website
#   Phase 9: Chaos Studio – resilience testing / fault injection
#
# Network Topology:
#
#   Branch 1 (HQ) – Central US          Branch 2 – East US 2
#   ┌──────────────────────┐             ┌──────────────────────┐
#   │  Hub VNet 10.0.0.0/16│             │ Hub VNet 10.1.0.0/16 │
#   │  ├─ GatewaySubnet    │◄── VPN ───► │  ├─ GatewaySubnet    │
#   │  └─ BastionSubnet    │             │  └─ (no bastion)     │
#   └─────────┬────────────┘             └─────────┬────────────┘
#             │ Peering                            │ Peering
#   ┌─────────┴────────── ──┐            ┌─────────┴─────────────┐
#   │Spoke VNet 10.10.0.0/16│            │Spoke VNet 10.20.0.0/16│
#   │  ├─ HR    10.10.0.0/24│            │  ├─ HR    10.20.0.0/24│
#   │  ├─ Fin   10.10.1.0/24│            │  ├─ Fin   10.20.1.0/24│
#   │  └─ IT   10.10.2.0/24 │            │  └─ IT   10.20.2.0/24 │
#   │     [NAT Gateway]     │            │     [NAT Gateway]     │
#   │  HR ──X── Finance     │            │  HR ──X── Finance     │
#   │(null route blackhole) │            │(null route blackhole) │
#   └───────────────────── ─┘            └───────────────────────┘
#
###############################################################################

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  RESOURCE GROUPS – One per branch (like a physical site)                  ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

resource "azurerm_resource_group" "branch1" {
  name     = "rg-mit565-branch1-hq"
  location = var.region_1
  tags     = var.tags
}

resource "azurerm_resource_group" "branch2" {
  name     = "rg-mit565-branch2"
  location = var.region_2
  tags     = var.tags
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 1: CORE NETWORKING                                                 ║
# ║  Branch 1 (HQ) – Hub-Spoke VNet with Bastion                              ║
# ║  Demonstrates: VLANs (subnets), trunk links (peering), CIDR               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "network_branch1" {
  source              = "./modules/hub-spoke-vnet"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  branch_name         = "branch1-hq"

  # Hub VNet – Core services
  hub_address_space     = ["10.0.0.0/16"]
  gateway_subnet_prefix = "10.0.1.0/27"
  bastion_subnet_prefix = "10.0.2.0/27"

  # Spoke VNet – Department subnets (VLANs)
  spoke_address_space   = ["10.10.0.0/16"]
  hr_subnet_prefix      = "10.10.0.0/24" # VLAN 10 – 254 hosts
  finance_subnet_prefix = "10.10.1.0/24" # VLAN 20 – 254 hosts
  it_subnet_prefix      = "10.10.2.0/24" # VLAN 30 – 254 hosts

  # Services
  bastion_enabled     = true
  nat_gateway_enabled = var.nat_gateway_enabled # Phase 2
  vpn_gateway_enabled = var.deploy_vpn          # Phase 7
  bgp_asn             = 65010
  tags                = var.tags
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 1: CORE NETWORKING                                                 ║
# ║  Branch 2 – Hub-Spoke VNet with VPN Gateway (connects to HQ)              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "network_branch2" {
  source              = "./modules/hub-spoke-vnet"
  resource_group_name = azurerm_resource_group.branch2.name
  region              = var.region_2
  branch_name         = "branch2"

  # Hub VNet – Core services
  hub_address_space     = ["10.1.0.0/16"]
  gateway_subnet_prefix = "10.1.1.0/27"
  bastion_subnet_prefix = "10.1.2.0/27"

  # Spoke VNet – Department subnets (VLANs)
  spoke_address_space   = ["10.20.0.0/16"]
  hr_subnet_prefix      = "10.20.0.0/24"
  finance_subnet_prefix = "10.20.1.0/24"
  it_subnet_prefix      = "10.20.2.0/24"

  # Branch 2: No Bastion – RDP to Branch 2 VMs from a Branch 1 VM via VPN
  bastion_enabled     = false
  nat_gateway_enabled = var.nat_gateway_enabled # Phase 2 – each branch needs its own NAT GW
  vpn_gateway_enabled = var.deploy_vpn # Phase 7
  bgp_asn             = 65020
  tags                = var.tags
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 7: VPN GATEWAY CONNECTION – Branch-to-Branch WAN Link              ║
# ║  Demonstrates: Site-to-site VPN, BGP dynamic routing                      ║
# ║  Like connecting two branch offices over an MPLS/Internet WAN link        ║
# ║  Toggle: var.deploy_vpn in terraform.tfvars                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

resource "azurerm_virtual_network_gateway_connection" "branch1_to_branch2" {
  count                           = var.deploy_vpn ? 1 : 0
  name                            = "vpn-branch1-to-branch2"
  location                        = var.region_1
  resource_group_name             = azurerm_resource_group.branch1.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.network_branch1.vpn_gateway_id
  peer_virtual_network_gateway_id = module.network_branch2.vpn_gateway_id
  shared_key                      = var.vpn_shared_key
  bgp_enabled                     = true
  tags                            = var.tags
}

resource "azurerm_virtual_network_gateway_connection" "branch2_to_branch1" {
  count                           = var.deploy_vpn ? 1 : 0
  name                            = "vpn-branch2-to-branch1"
  location                        = var.region_2
  resource_group_name             = azurerm_resource_group.branch2.name
  type                            = "Vnet2Vnet"
  virtual_network_gateway_id      = module.network_branch2.vpn_gateway_id
  peer_virtual_network_gateway_id = module.network_branch1.vpn_gateway_id
  shared_key                      = var.vpn_shared_key
  bgp_enabled                     = true
  tags                            = var.tags
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 3: NSGs – Network Security Groups (ACLs)                           ║
# ║  Applied per-department per-branch                                        ║
# ║  Toggle: var.deploy_nsgs in terraform.tfvars                              ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "nsg_branch1" {
  count               = var.deploy_nsgs ? 1 : 0
  source              = "./modules/nsg"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  branch_name         = "branch1-hq"

  hr_subnet_id          = module.network_branch1.hr_subnet_id
  finance_subnet_id     = module.network_branch1.finance_subnet_id
  it_subnet_id          = module.network_branch1.it_subnet_id
  hr_subnet_prefix      = "10.10.0.0/24"
  finance_subnet_prefix = "10.10.1.0/24"
  it_subnet_prefix      = "10.10.2.0/24"
  tags                  = var.tags

  depends_on = [module.network_branch1]
}

module "nsg_branch2" {
  count               = var.deploy_nsgs ? 1 : 0
  source              = "./modules/nsg"
  resource_group_name = azurerm_resource_group.branch2.name
  region              = var.region_2
  branch_name         = "branch2"

  hr_subnet_id          = module.network_branch2.hr_subnet_id
  finance_subnet_id     = module.network_branch2.finance_subnet_id
  it_subnet_id          = module.network_branch2.it_subnet_id
  hr_subnet_prefix      = "10.20.0.0/24"
  finance_subnet_prefix = "10.20.1.0/24"
  it_subnet_prefix      = "10.20.2.0/24"
  tags                  = var.tags

  depends_on = [module.network_branch2]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 4: ROUTE TABLES – User-Defined Routes (Static Routing)             ║
# ║  Demonstrates: Routing tables, static routes, UDR concepts                ║
# ║  Toggle: var.deploy_route_tables in terraform.tfvars                      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "routes_branch1" {
  count               = var.deploy_route_tables ? 1 : 0
  source              = "./modules/route-tables"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  branch_name         = "branch1-hq"

  hr_subnet_id          = module.network_branch1.hr_subnet_id
  finance_subnet_id     = module.network_branch1.finance_subnet_id
  it_subnet_id          = module.network_branch1.it_subnet_id
  hr_subnet_prefix      = "10.10.0.0/24"
  finance_subnet_prefix = "10.10.1.0/24"
  tags                  = var.tags

  depends_on = [module.network_branch1]
}

module "routes_branch2" {
  count               = var.deploy_route_tables ? 1 : 0
  source              = "./modules/route-tables"
  resource_group_name = azurerm_resource_group.branch2.name
  region              = var.region_2
  branch_name         = "branch2"

  hr_subnet_id          = module.network_branch2.hr_subnet_id
  finance_subnet_id     = module.network_branch2.finance_subnet_id
  it_subnet_id          = module.network_branch2.it_subnet_id
  hr_subnet_prefix      = "10.20.0.0/24"
  finance_subnet_prefix = "10.20.1.0/24"
  tags                  = var.tags

  depends_on = [module.network_branch2]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 5: DNS – Azure Private DNS Zone                                    ║
# ║  Demonstrates: A records, name resolution, DNS zones, nslookup            ║
# ║  Toggle: var.deploy_dns in terraform.tfvars                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "dns" {
  count               = var.deploy_dns ? 1 : 0
  source              = "./modules/dns"
  resource_group_name = azurerm_resource_group.branch1.name
  dns_zone_name       = "mit565.local"

  # Link all spoke VNets so VMs can resolve names across branches
  vnet_links = {
    "spoke-branch1" = module.network_branch1.spoke_vnet_id
    "spoke-branch2" = module.network_branch2.spoke_vnet_id
    "hub-branch1"   = module.network_branch1.hub_vnet_id
    "hub-branch2"   = module.network_branch2.hub_vnet_id
  }

  # Manual A records (like DNS zone file entries)
  dns_records = {
    "dns-server"     = "10.10.2.10"
    "web-server"     = "10.10.2.20"
    "branch1-client" = "10.10.0.10"
    "branch2-client" = "10.20.0.10"
  }

  tags = var.tags

  depends_on = [module.network_branch1, module.network_branch2]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 5: WINDOWS SERVER – DNS Server at HQ (Branch 1, IT Subnet)         ║
# ║  Static IP 10.10.2.10 – demonstrates DNS server role                      ║
# ║  Toggle: var.deploy_dns in terraform.tfvars                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "dns_server" {
  count               = var.deploy_dns ? 1 : 0
  source              = "./modules/windows-server"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  subnet_id           = module.network_branch1.it_subnet_id
  vm_name             = "dns-server"
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  private_ip_address  = "10.10.2.10"
  install_dns         = true
  dns_servers         = ["168.63.129.16"]
  use_spot            = var.use_spot
  tags                = var.tags

  depends_on = [module.network_branch1]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 6: WINDOWS CLIENTS – Workstations in department subnets            ║
# ║  Demonstrates: DHCP (dynamic IP), DNS client config, ARP behavior         ║
# ║  Toggle: var.deploy_clients in terraform.tfvars                           ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# Branch 1 – HR Department workstation
module "client_branch1_hr" {
  count               = var.deploy_clients ? 1 : 0
  source              = "./modules/windows-clients"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  subnet_id           = module.network_branch1.hr_subnet_id
  vm_name             = "b1-hr-pc1"
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  dns_servers         = ["10.10.2.10"]
  use_spot            = var.use_spot
  tags                = var.tags

  depends_on = [module.network_branch1]
}

# Branch 1 – Finance Department workstation
module "client_branch1_fin" {
  count               = var.deploy_clients ? 1 : 0
  source              = "./modules/windows-clients"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  subnet_id           = module.network_branch1.finance_subnet_id
  vm_name             = "b1-fin-pc1"
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  dns_servers         = ["10.10.2.10"]
  use_spot            = var.use_spot
  tags                = var.tags

  depends_on = [module.network_branch1]
}

# Branch 2 – HR Department workstation (tests cross-branch connectivity)
module "client_branch2_hr" {
  count               = var.deploy_clients ? 1 : 0
  source              = "./modules/windows-clients"
  resource_group_name = azurerm_resource_group.branch2.name
  region              = var.region_2
  subnet_id           = module.network_branch2.hr_subnet_id
  vm_name             = "b2-hr-pc1"
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  dns_servers         = ["10.10.2.10"]
  use_spot            = var.use_spot
  tags                = var.tags

  depends_on = [module.network_branch2]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 8: STORAGE + WEB SERVER                                            ║
# ║  Hosts web content for IIS deployment                                     ║
# ║  Toggle: var.deploy_web_server in terraform.tfvars                        ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

resource "random_string" "storage_suffix" {
  count   = var.deploy_web_server ? 1 : 0
  length  = 8
  special = false
  upper   = false
}

resource "azurerm_storage_account" "web_content" {
  count                    = var.deploy_web_server ? 1 : 0
  name                     = "stmit565web${random_string.storage_suffix[0].result}"
  resource_group_name      = azurerm_resource_group.branch1.name
  location                 = var.region_1
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = var.tags
}

resource "azurerm_storage_container" "web_content" {
  count                 = var.deploy_web_server ? 1 : 0
  name                  = "webcontent"
  storage_account_id    = azurerm_storage_account.web_content[0].id
  container_access_type = "blob"
}

resource "azurerm_storage_blob" "website_html" {
  count                  = var.deploy_web_server ? 1 : 0
  name                   = "index.html"
  storage_account_name   = azurerm_storage_account.web_content[0].name
  storage_container_name = azurerm_storage_container.web_content[0].name
  type                   = "Block"
  content_type           = "text/html"
  source_content         = <<-HTML
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>MIT 565 - Internetworking Azure Lab</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body { font-family: Segoe UI, Tahoma, Geneva, Verdana, sans-serif; background: #0a0a1a; color: #e0e0e0; line-height: 1.7; }
    .header { background: linear-gradient(135deg, #1a1a3e 0%, #0d47a1 50%, #004d40 100%); padding: 60px 20px; text-align: center; border-bottom: 4px solid #00bcd4; }
    .header h1 { font-size: 2.5em; color: #00e5ff; text-shadow: 0 0 20px rgba(0,229,255,0.3); margin-bottom: 10px; }
    .header p { font-size: 1.2em; color: #b0bec5; }
    .header .badge { display: inline-block; background: #00bcd4; color: #000; padding: 5px 15px; border-radius: 20px; font-weight: bold; margin-top: 15px; }
    .container { max-width: 1200px; margin: 0 auto; padding: 40px 20px; }
    .section { background: #111133; border: 1px solid #1a237e; border-radius: 12px; padding: 30px; margin-bottom: 30px; box-shadow: 0 4px 15px rgba(0,0,0,0.3); }
    .section h2 { color: #00e5ff; font-size: 1.6em; margin-bottom: 20px; padding-bottom: 10px; border-bottom: 2px solid #1a237e; }
    .section h3 { color: #4fc3f7; margin-top: 20px; margin-bottom: 10px; }
    table { width: 100%; border-collapse: collapse; margin: 15px 0; }
    th { background: #1a237e; color: #00e5ff; padding: 12px 15px; text-align: left; font-weight: 600; }
    td { padding: 10px 15px; border-bottom: 1px solid #1a1a3e; }
    tr:hover { background: #1a1a3e; }
    .concept-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); gap: 20px; margin-top: 20px; }
    .concept-card { background: #0d0d2b; border: 1px solid #283593; border-radius: 8px; padding: 20px; transition: transform 0.2s, border-color 0.2s; }
    .concept-card:hover { transform: translateY(-3px); border-color: #00bcd4; }
    .concept-card .icon { font-size: 2em; margin-bottom: 10px; }
    .concept-card h3 { color: #00e5ff; margin-bottom: 8px; }
    .concept-card .class-label { color: #ff9800; font-weight: bold; font-size: 0.85em; }
    .concept-card .azure-label { color: #00bcd4; font-weight: bold; font-size: 0.85em; }
    .topology-box { background: #0a0a2e; border: 2px solid #1a237e; border-radius: 8px; padding: 20px; font-family: Consolas, monospace; font-size: 0.9em; white-space: pre; overflow-x: auto; line-height: 1.4; color: #4fc3f7; }
    code { background: #1a1a3e; color: #00e5ff; padding: 2px 8px; border-radius: 4px; font-family: Consolas, monospace; font-size: 0.9em; }
    .cmd-block { background: #0a0a2e; border-left: 4px solid #00bcd4; padding: 15px 20px; margin: 10px 0; font-family: Consolas, monospace; font-size: 0.9em; border-radius: 0 8px 8px 0; }
    .cmd-block .prompt { color: #ff9800; }
    .cmd-block .cmd { color: #00e5ff; }
    .cmd-block .comment { color: #616161; }
    .ip-scheme { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }
    .ip-branch { background: #0d0d2b; border-radius: 8px; padding: 20px; border: 1px solid #283593; }
    .ip-branch h3 { text-align: center; margin-bottom: 15px; }
    .highlight { color: #ffeb3b; font-weight: bold; }
    .success { color: #66bb6a; }
    .deny { color: #ef5350; }
    .footer { text-align: center; padding: 30px; color: #616161; border-top: 1px solid #1a237e; margin-top: 40px; }
    @media (max-width: 768px) { .ip-scheme { grid-template-columns: 1fr; } .concept-grid { grid-template-columns: 1fr; } .header h1 { font-size: 1.8em; } }
  </style>
</head>
<body>

<div class="header">
  <h1>MIT 565 - Internetworking</h1>
  <p>Azure Cloud Lab - Network Infrastructure Documentation</p>
  <div class="badge">Elmhurst University - MCIT Program</div>
</div>

<div class="container">

  <!-- PROJECT OVERVIEW -->
  <div class="section">
    <h2>Project Overview</h2>
    <p>This Azure lab environment demonstrates every core networking concept from MIT 565 Internetworking, translated from physical Cisco equipment to Microsoft Azure cloud infrastructure. The lab proves that <strong>cloud is not magic - it is virtualized networking with the same TCP/IP fundamentals underneath.</strong></p>
    <div class="concept-grid">
      <div class="concept-card">
        <div class="icon">&#127959;</div>
        <h3>Architecture</h3>
        <p>Hub-spoke topology across 2 Azure regions simulating branch offices connected by VPN (WAN links) with department segmentation.</p>
      </div>
      <div class="concept-card">
        <div class="icon">&#128274;</div>
        <h3>Security</h3>
        <p>Network Security Groups act as ACLs, providing per-subnet traffic filtering and access control.</p>
      </div>
      <div class="concept-card">
        <div class="icon">&#128225;</div>
        <h3>DNS</h3>
        <p>Windows DNS server + Azure Private DNS zones demonstrate name resolution, A records, and nslookup troubleshooting.</p>
      </div>
      <div class="concept-card">
        <div class="icon">&#128268;</div>
        <h3>Routing</h3>
        <p>User-Defined Routes (null routes/blackholes for department isolation, static routes) and VPN Gateway BGP (dynamic routing) control traffic flow between subnets and branches.</p>
      </div>
      <div class="concept-card">
        <div class="icon">&#128165;</div>
        <h3>Chaos Engineering</h3>
        <p>Azure Chaos Studio injects controlled failures (server shutdowns, NSG deny-all) to test resilience and teach incident response.</p>
      </div>
    </div>
  </div>

  <!-- CONCEPT MAPPING -->
  <div class="section">
    <h2>MIT 565 Concept to Azure Mapping</h2>
    <table>
      <tr><th>MIT 565 Concept</th><th>In-Class Tool</th><th>Azure Equivalent</th><th>Where in This Lab</th></tr>
      <tr><td>VLANs</td><td>Switch VLAN config</td><td>Subnets</td><td>HR, Finance, IT subnets per branch</td></tr>
      <tr><td>Trunk Links</td><td>802.1Q trunking</td><td>VNet Peering</td><td>Hub-to-Spoke peering</td></tr>
      <tr><td>IP Addressing (CIDR)</td><td>Subnet masks, /24</td><td>Address spaces</td><td>10.x.x.x/16 and /24 prefixes</td></tr>
      <tr><td>Default Gateway</td><td>Router interface IP</td><td>Azure virtual router</td><td>Azure SDN default gateway per subnet</td></tr>
      <tr><td>Static Routing</td><td>ip route command</td><td>User-Defined Routes (UDR)</td><td>Null routes (blackhole) between HR↔Finance</td></tr>
      <tr><td>Dynamic Routing (OSPF/BGP)</td><td>router ospf config</td><td>VPN Gateway BGP</td><td>BGP-enabled VPN gateways</td></tr>
      <tr><td>Standard ACLs</td><td>access-list (source)</td><td>NSG (source filter)</td><td>NSG rules per department</td></tr>
      <tr><td>Extended ACLs</td><td>access-list (src/dst/port)</td><td>NSG (src/dst/port/proto)</td><td>RDP allow/deny rules</td></tr>
      <tr><td>DNS (A/AAAA records)</td><td>DNS server, nslookup</td><td>Private DNS Zone + Windows DNS</td><td>mit565.local zone</td></tr>
      <tr><td>ARP</td><td>arp -a, show arp</td><td>VM NIC ARP tables</td><td>Run arp -a on any VM</td></tr>
      <tr><td>NAT</td><td>ip nat inside/outside</td><td>NAT Gateway (SNAT)</td><td>NAT Gateway on both branches (outbound internet)</td></tr>
      <tr><td>WAN Links</td><td>Serial/MPLS connections</td><td>VPN Gateway connections</td><td>Branch1-to-Branch2 VPN tunnel</td></tr>
      <tr><td>Chaos/Failure Testing</td><td>Pulling cables, shutdown interface</td><td>Azure Chaos Studio</td><td>DNS outage, web outage, NSG deny-all experiments</td></tr>
    </table>
  </div>

  <!-- NETWORK TOPOLOGY -->
  <div class="section">
    <h2>Network Topology</h2>
<div class="topology-box">
    Branch 1 (HQ) - Central US                    Branch 2 - East US 2

    +========================+                     +========================+
    |   Hub VNet 10.0.0.0/16 |                     |  Hub VNet 10.1.0.0/16  |
    |   +------------------+ |    VPN Tunnel       |  +------------------+  |
    |   | GatewaySubnet    |=|======(BGP)===========|==| GatewaySubnet    |  |
    |   | 10.0.1.0/27      | |    (Shared Key)     |  | 10.1.1.0/27      |  |
    |   +------------------+ |                     |  +------------------+  |
    |   | BastionSubnet    | |                     |                        |
    |   | 10.0.2.0/27      | |                     +===========+============+
    |   +------------------+ |                                 |
    +=========+=============++                          VNet Peering                     +============+===========+
              |                                    | Spoke VNet 10.20.0.0/16|
       VNet Peering                                |  +------------------+  |
              |                                    |  | snet-hr (VLAN10) |  |
    +==========+==============+                    |  | 10.20.0.0/24     |  |
    | Spoke VNet 10.10.0.0/16 |                    |  +------------------+  |
    |  +--------------------+ |                    |  | snet-fin (VLAN20)|  |
    |  | snet-hr  (VLAN 10) | |                    |  | 10.20.1.0/24     |  |
    |  | 10.10.0.0/24       | |                    |  +------------------+  |
    |  |   [b1-hr-pc1]      | |                    |  | snet-it (VLAN30) |  |
    |  +--------------------+ |                    |  | 10.20.2.0/24     |  |
    |  | snet-fin (VLAN 20) | |                    |  |   [b2-hr-pc1]    |  |
    |  | 10.10.1.0/24       | |                    |  +------------------+  |
    |  |   [b1-fin-pc1]     | |                    |  [NAT Gateway]         |
    |  +--------------------+ |                    |  HR --X-- Finance      |
    |  | snet-it  (VLAN 30) | |                    |  (null route blackhole)|
    |  | 10.10.2.0/24       | |                    +========================+
    |  |   [dns-server]     | |
    |  |   [web-server]     | |
    |  +--------------------+ |
    |  [NAT Gateway]          |
    |  HR --X-- Finance       |
    |  (null route blackhole) |
    +=========================+
</div>
  </div>

  <!-- IP ADDRESSING SCHEME -->
  <div class="section">
    <h2>IP Addressing Scheme (CIDR)</h2>
    <p>Demonstrates classless addressing with /16 supernets divided into /24 department subnets (254 usable hosts each).</p>
    <div class="ip-scheme">
      <div class="ip-branch">
        <h3 class="highlight">Branch 1 - HQ (Central US)</h3>
        <table>
          <tr><th>Network</th><th>CIDR</th><th>Usable Range</th></tr>
          <tr><td>Hub VNet</td><td>10.0.0.0/16</td><td>10.0.0.1 - 10.0.255.254</td></tr>
          <tr><td>GatewaySubnet</td><td>10.0.1.0/27</td><td>10.0.1.1 - 10.0.1.30</td></tr>
          <tr><td>BastionSubnet</td><td>10.0.2.0/27</td><td>10.0.2.1 - 10.0.2.30</td></tr>
          <tr><td>Spoke VNet</td><td>10.10.0.0/16</td><td>10.10.0.1 - 10.10.255.254</td></tr>
          <tr><td>HR Subnet</td><td>10.10.0.0/24</td><td>10.10.0.1 - 10.10.0.254</td></tr>
          <tr><td>Finance Subnet</td><td>10.10.1.0/24</td><td>10.10.1.1 - 10.10.1.254</td></tr>
          <tr><td>IT Subnet</td><td>10.10.2.0/24</td><td>10.10.2.1 - 10.10.2.254</td></tr>
        </table>
        <h3>Static Assignments</h3>
        <table>
          <tr><th>Host</th><th>IP Address</th><th>Role</th></tr>
          <tr><td>dns-server</td><td>10.10.2.10</td><td>Windows DNS Server</td></tr>
          <tr><td>web-server</td><td>10.10.2.20</td><td>IIS Web Server</td></tr>
          <tr><td>b1-hr-pc1</td><td>Dynamic (DHCP)</td><td>HR Workstation</td></tr>
          <tr><td>b1-fin-pc1</td><td>Dynamic (DHCP)</td><td>Finance Workstation</td></tr>
        </table>
      </div>
      <div class="ip-branch">
        <h3 class="highlight">Branch 2 (East US 2)</h3>
        <table>
          <tr><th>Network</th><th>CIDR</th><th>Usable Range</th></tr>
          <tr><td>Hub VNet</td><td>10.1.0.0/16</td><td>10.1.0.1 - 10.1.255.254</td></tr>
          <tr><td>GatewaySubnet</td><td>10.1.1.0/27</td><td>10.1.1.1 - 10.1.1.30</td></tr>
          <tr><td>Spoke VNet</td><td>10.20.0.0/16</td><td>10.20.0.1 - 10.20.255.254</td></tr>
          <tr><td>HR Subnet</td><td>10.20.0.0/24</td><td>10.20.0.1 - 10.20.0.254</td></tr>
          <tr><td>Finance Subnet</td><td>10.20.1.0/24</td><td>10.20.1.1 - 10.20.1.254</td></tr>
          <tr><td>IT Subnet</td><td>10.20.2.0/24</td><td>10.20.2.1 - 10.20.2.254</td></tr>
        </table>
        <h3>Static Assignments</h3>
        <table>
          <tr><th>Host</th><th>IP Address</th><th>Role</th></tr>
          <tr><td>b2-hr-pc1</td><td>Dynamic (DHCP)</td><td>HR Workstation</td></tr>
        </table>
      </div>
    </div>
  </div>

  <!-- SECURITY (NSG/ACL) -->
  <div class="section">
    <h2>Security Rules (NSGs = ACLs)</h2>
    <p>Each department subnet has its own NSG, just like each switch interface would have an ACL applied.</p>
    <h3>IT Department (Admin VLAN) - Full Access</h3>
    <table>
      <tr><th>Priority</th><th>Direction</th><th>Action</th><th>Source</th><th>Dest Port</th><th>Cisco ACL Equivalent</th></tr>
      <tr><td>100</td><td>Inbound</td><td class="success">Allow</td><td>VirtualNetwork</td><td>*</td><td><code>permit ip any any</code></td></tr>
      <tr><td>100</td><td>Outbound</td><td class="success">Allow</td><td>*</td><td>*</td><td><code>permit ip any any</code></td></tr>
    </table>
    <h3>HR Department - Limited Access</h3>
    <table>
      <tr><th>Priority</th><th>Direction</th><th>Action</th><th>Source</th><th>Dest Port</th><th>Cisco ACL Equivalent</th></tr>
      <tr><td>100</td><td>Inbound</td><td class="success">Allow</td><td>IT Subnet</td><td>ICMP</td><td><code>permit icmp 10.10.2.0 0.0.0.255 any</code></td></tr>
      <tr><td>110</td><td>Inbound</td><td class="success">Allow</td><td>IT Subnet</td><td>3389</td><td><code>permit tcp 10.10.2.0 0.0.0.255 any eq 3389</code></td></tr>
      <tr><td>200</td><td>Inbound</td><td class="deny">Deny</td><td>Finance Subnet</td><td>3389</td><td><code>deny tcp 10.10.1.0 0.0.0.255 any eq 3389</code></td></tr>
    </table>
    <h3>Finance Department - Isolated</h3>
    <table>
      <tr><th>Priority</th><th>Direction</th><th>Action</th><th>Source</th><th>Dest Port</th><th>Cisco ACL Equivalent</th></tr>
      <tr><td>100</td><td>Inbound</td><td class="success">Allow</td><td>IT Subnet</td><td>ICMP</td><td><code>permit icmp 10.10.2.0 0.0.0.255 any</code></td></tr>
      <tr><td>110</td><td>Inbound</td><td class="success">Allow</td><td>IT Subnet</td><td>3389</td><td><code>permit tcp 10.10.2.0 0.0.0.255 any eq 3389</code></td></tr>
      <tr><td>200</td><td>Inbound</td><td class="deny">Deny</td><td>HR Subnet</td><td>3389</td><td><code>deny tcp 10.10.0.0 0.0.0.255 any eq 3389</code></td></tr>
    </table>
  </div>

  <!-- ROUTING -->
  <div class="section">
    <h2>Routing Configuration</h2>
    <h3>Null Routes (Blackhole) – Defense in Depth</h3>
    <p>Route tables use <strong>null routes</strong> (<code>next_hop_type = "None"</code>) to drop traffic between HR and Finance at the <strong>routing layer (Layer 3)</strong>. This creates <strong>defense in depth</strong> with NSGs — traffic is blocked at two independent layers. Even if an NSG rule is misconfigured, the null route still stops the packets.</p>
    <table>
      <tr><th>Route Table</th><th>Destination</th><th>Next Hop</th><th>Effect</th><th>Cisco Equivalent</th></tr>
      <tr><td>rt-hr</td><td>Finance Subnet</td><td class="deny">None (Blackhole)</td><td class="deny">DROP</td><td><code>ip route 10.x.1.0 255.255.255.0 Null0</code></td></tr>
      <tr><td>rt-finance</td><td>HR Subnet</td><td class="deny">None (Blackhole)</td><td class="deny">DROP</td><td><code>ip route 10.x.0.0 255.255.255.0 Null0</code></td></tr>
      <tr><td>rt-it</td><td>(no blocking routes)</td><td>—</td><td class="success">ALLOW ALL</td><td><code>! no null routes – IT has full access</code></td></tr>
    </table>
    <div class="cmd-block">
      <span class="comment"># Defense in Depth: Two independent layers blocking HR↔Finance</span><br>
      <span class="comment"># Layer 3 (Routing): Null route drops packets before they reach the destination</span><br>
      <span class="prompt">Router(config)#</span> <span class="cmd">ip route 10.10.1.0 255.255.255.0 Null0</span><br>
      <span class="comment">! Cisco equivalent: route to Null0 = silently discard</span><br><br>
      <span class="comment"># Layer 4 (ACLs/NSGs): NSG also denies HR↔Finance RDP</span><br>
      <span class="comment">! Even if you remove the null route, the NSG still blocks RDP</span><br>
      <span class="comment">! Even if you remove the NSG rule, the null route still drops ALL traffic</span>
    </div>
    <h3>NAT Gateway (Both Branches)</h3>
    <p>Each branch has its own NAT Gateway providing outbound internet access via SNAT. NAT Gateway handles outbound internet automatically — no UDR needed for internet access.</p>
    <div class="cmd-block">
      <span class="comment"># Cisco equivalent:</span><br>
      <span class="prompt">Router(config)#</span> <span class="cmd">ip nat inside source list 1 interface GigabitEthernet0/0 overload</span><br>
      <span class="comment">! NAT Gateway = PAT/NAT overload for outbound internet</span>
    </div>
    <h3>BGP Dynamic Routing (VPN Gateways)</h3>
    <p>VPN Gateways exchange routes between branches using BGP. Route tables have <code>bgp_route_propagation_enabled = true</code> so these learned routes reach department subnets.</p>
    <div class="cmd-block">
      <span class="comment"># BGP on VPN Gateways automatically exchanges routes between branches</span><br>
      <span class="comment"># Branch 1: router bgp 65010</span><br>
      <span class="comment"># Branch 2: router bgp 65020</span><br>
      <span class="comment"># Similar to: router bgp 65010 / neighbor x.x.x.x remote-as 65020</span>
    </div>
  </div>

  <!-- DNS -->
  <div class="section">
    <h2>DNS Configuration</h2>
    <h3>Azure Private DNS Zone: <code>mit565.local</code></h3>
    <table>
      <tr><th>Record Type</th><th>Hostname</th><th>Value</th><th>TTL</th></tr>
      <tr><td>A</td><td>dns-server.mit565.local</td><td>10.10.2.10</td><td>300</td></tr>
      <tr><td>A</td><td>web-server.mit565.local</td><td>10.10.2.20</td><td>300</td></tr>
      <tr><td>A</td><td>branch1-client.mit565.local</td><td>10.10.0.10</td><td>300</td></tr>
      <tr><td>A</td><td>branch2-client.mit565.local</td><td>10.20.0.10</td><td>300</td></tr>
    </table>
    <h3>Lab Exercises - DNS</h3>
    <div class="cmd-block">
      <span class="prompt">C:\&gt;</span> <span class="cmd">nslookup web-server.mit565.local</span><br>
      <span class="comment">Server:  dns-server.mit565.local</span><br>
      <span class="comment">Address: 10.10.2.10</span><br><br>
      <span class="comment">Name:    web-server.mit565.local</span><br>
      <span class="comment">Address: 10.10.2.20</span><br><br>
      <span class="prompt">C:\&gt;</span> <span class="cmd">Resolve-DnsName -Name web-server.mit565.local -Type A</span>
    </div>
  </div>

  <!-- LAB EXERCISES -->
  <div class="section">
    <h2>Lab Exercises</h2>
    <div class="concept-grid">
      <div class="concept-card">
        <h3>1. IP Addressing and Subnetting</h3>
        <div class="cmd-block">
          <span class="prompt">C:\&gt;</span> <span class="cmd">ipconfig /all</span><br>
          <span class="comment">Verify: IP, subnet mask (/24 = 255.255.255.0), default gateway, DNS server</span>
        </div>
      </div>
      <div class="concept-card">
        <h3>2. ARP and MAC Addresses</h3>
        <div class="cmd-block">
          <span class="prompt">C:\&gt;</span> <span class="cmd">arp -a</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">ping 10.10.1.x</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">arp -a</span><br>
          <span class="comment">Watch new MAC entry appear!</span>
        </div>
      </div>
      <div class="concept-card">
        <h3>3. DNS Resolution</h3>
        <div class="cmd-block">
          <span class="prompt">C:\&gt;</span> <span class="cmd">nslookup dns-server.mit565.local</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">nslookup web-server.mit565.local</span>
        </div>
      </div>
      <div class="concept-card">
        <h3>4. Routing Tables &amp; Null Routes (UDRs)</h3>
        <div class="cmd-block">
          <span class="prompt">C:\&gt;</span> <span class="cmd">route print</span><br>
          <span class="comment">View the Windows routing table</span><br><br>
          <span class="comment">Test null route (from HR VM):</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">ping 10.10.1.x</span> <span class="deny">BLOCKED (null route)</span><br>
          <span class="comment">HR cannot reach Finance – packets are blackholed at Layer 3!</span><br><br>
          <span class="comment">Test cross-branch routing:</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">tracert 10.20.0.x</span><br>
          <span class="comment">Trace path to Branch 2 via VPN (BGP route)</span><br><br>
          <span class="comment">Defense in depth test:</span><br>
          <span class="comment">Even if the NSG deny rule is removed,</span><br>
          <span class="comment">the null route STILL blocks HR↔Finance traffic</span>
        </div>
      </div>
      <div class="concept-card">
        <h3>5. NSG/ACL Testing</h3>
        <div class="cmd-block">
          <span class="comment">From HR VM:</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">ping 10.10.1.x</span> <span class="success">OK</span><br>
          <span class="comment">From HR to Finance RDP:</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">mstsc /v:10.10.1.x</span> <span class="deny">BLOCKED</span>
        </div>
      </div>
      <div class="concept-card">
        <h3>6. Web Server (HTTP over TCP)</h3>
        <div class="cmd-block">
          <span class="prompt">C:\&gt;</span> <span class="cmd">curl http://10.10.2.20</span><br>
          <span class="prompt">C:\&gt;</span> <span class="cmd">curl http://web-server.mit565.local</span><br>
          <span class="comment">Full TCP/IP stack in action!</span>
        </div>
      </div>
    </div>
  </div>

  <!-- TCP/IP STACK -->
  <div class="section">
    <h2>End-to-End: How This Page Reached Your Browser</h2>
    <p>When you opened <code>http://web-server.mit565.local</code> from a client VM, every layer of the TCP/IP stack was involved:</p>
    <table>
      <tr><th>Layer</th><th>TCP/IP Model</th><th>What Happened</th><th>Azure Component</th></tr>
      <tr><td>5</td><td>Application</td><td>Browser sent HTTP GET request for index.html</td><td>IIS Web Server on this VM</td></tr>
      <tr><td>4</td><td>Transport</td><td>TCP 3-way handshake (SYN, SYN-ACK, ACK) on port 80</td><td>Azure SDN TCP stack</td></tr>
      <tr><td>3</td><td>Internet</td><td>IP packet routed: client IP to 10.10.2.20</td><td>UDR / Azure virtual router</td></tr>
      <tr><td>2</td><td>Network Access</td><td>Frame sent with destination MAC (ARP resolved)</td><td>Azure virtual switch / NIC</td></tr>
      <tr><td>1</td><td>Physical</td><td>Bits transmitted over Azure backbone fiber</td><td>Azure datacenter fabric</td></tr>
    </table>
  </div>

  <!-- INFRASTRUCTURE AS CODE -->
  <div class="section">
    <h2>Infrastructure as Code (Terraform)</h2>
    <p>This entire lab was deployed using <strong>HashiCorp Terraform</strong> - an Infrastructure as Code (IaC) tool that defines cloud resources in declarative configuration files.</p>
    <table>
      <tr><th>Module</th><th>Purpose</th><th>Resources Created</th></tr>
      <tr><td><code>hub-spoke-vnet</code></td><td>Network topology</td><td>Hub/Spoke VNets, subnets, peering, Bastion, NAT Gateway, VPN Gateway</td></tr>
      <tr><td><code>nsg</code></td><td>Security (ACLs)</td><td>NSGs with permit/deny rules per department</td></tr>
      <tr><td><code>route-tables</code></td><td>Routing</td><td>Route tables with null routes (HR↔Finance blackhole) + BGP propagation</td></tr>
      <tr><td><code>dns</code></td><td>Name resolution</td><td>Private DNS zone, A records, VNet links</td></tr>
      <tr><td><code>windows-server</code></td><td>Server VMs</td><td>DNS server, Web server (this page!)</td></tr>
      <tr><td><code>windows-clients</code></td><td>Workstations</td><td>Department workstation VMs</td></tr>
    </table>
    <p style="margin-top: 15px;"><strong>Chaos Studio</strong> (Phase 9) is configured directly in <code>main.tf</code> — targets, capabilities, experiments, and role assignments for fault injection testing.</p>
  </div>

  <!-- MANAGEMENT ACCESS -->
  <div class="section">
    <h2>Management Access</h2>
    <h3>Azure Bastion (Branch 1 Only)</h3>
    <p>Azure Bastion provides secure RDP access to Branch 1 VMs without exposing public IP addresses. It supports both browser-based and native RDP client connections (tunneling enabled).</p>
    <div class="cmd-block">
      <span class="comment"># Connect via native RDP client (from your local machine):</span><br>
      <span class="prompt">$</span> <span class="cmd">az network bastion tunnel --name bastion-branch1-hq \</span><br>
      <span class="cmd">    --resource-group rg-mit565-branch1-hq \</span><br>
      <span class="cmd">    --target-resource-id /subscriptions/.../virtualMachines/VM_NAME \</span><br>
      <span class="cmd">    --resource-port 3389 --port 3389</span><br><br>
      <span class="comment"># Then open Remote Desktop Connection to localhost:3389</span>
    </div>
    <h3>Accessing Branch 2 VMs</h3>
    <p>Branch 2 has no Bastion host (simulating a remote branch office). To access Branch 2 VMs:</p>
    <div class="cmd-block">
      <span class="comment"># 1. Bastion into any Branch 1 VM (e.g., b1-hr-pc1)</span><br>
      <span class="comment"># 2. From that VM, open Remote Desktop (mstsc)</span><br>
      <span class="prompt">C:\&gt;</span> <span class="cmd">mstsc /v:10.20.0.x</span><br>
      <span class="comment"># This proves cross-branch VPN connectivity!</span>
    </div>
  </div>

  <!-- CHAOS STUDIO -->
  <div class="section">
    <h2>Chaos Studio – Resilience Testing</h2>
    <p><strong>Azure Chaos Studio</strong> lets you inject controlled failures into your infrastructure to test resilience. This is the cloud equivalent of pulling cables, shutting interfaces, or misconfiguring ACLs — but in a safe, repeatable, and time-limited way.</p>
    <h3>Experiments</h3>
    <table>
      <tr><th>Experiment</th><th>What It Does</th><th>Duration</th><th>What Students Observe</th><th>Cisco Equivalent</th></tr>
      <tr><td><code>chaos-dns-outage</code></td><td>Shuts down DNS server VM</td><td>5 min</td><td class="deny">nslookup fails, ping by IP still works</td><td><code>shutdown</code> on DNS server interface</td></tr>
      <tr><td><code>chaos-web-outage</code></td><td>Shuts down IIS web server VM</td><td>5 min</td><td class="deny">HTTP fails, DNS still resolves name</td><td><code>shutdown</code> on web server interface</td></tr>
      <tr><td><code>chaos-hr-network-partition</code></td><td>Injects deny-all NSG rule on HR subnet</td><td>5 min</td><td class="deny">HR VM completely isolated</td><td><code>deny ip any any</code> on interface</td></tr>
    </table>
    <h3>How to Run an Experiment</h3>
    <div class="cmd-block">
      <span class="comment"># 1. Open Azure Portal → search "Chaos Studio"</span><br>
      <span class="comment"># 2. Click "Experiments" in the left menu</span><br>
      <span class="comment"># 3. Select an experiment (e.g., chaos-dns-outage)</span><br>
      <span class="comment"># 4. Click "Start" → Confirm</span><br>
      <span class="comment"># 5. Monitor from a client VM — test connectivity during the fault</span><br>
      <span class="comment"># 6. After 5 minutes, the fault auto-reverts (VM restarts / NSG rule removed)</span>
    </div>
    <h3>Lab Exercise – Chaos Engineering</h3>
    <div class="cmd-block">
      <span class="comment">## Before starting the DNS outage experiment:</span><br>
      <span class="prompt">C:\&gt;</span> <span class="cmd">nslookup web-server.mit565.local</span> <span class="success">→ 10.10.2.20</span><br>
      <span class="prompt">C:\&gt;</span> <span class="cmd">ping 10.10.2.10</span> <span class="success">→ Reply</span><br><br>
      <span class="comment">## Start "chaos-dns-outage" in Azure Portal, then:</span><br>
      <span class="prompt">C:\&gt;</span> <span class="cmd">nslookup web-server.mit565.local</span> <span class="deny">→ TIMEOUT (DNS server down!)</span><br>
      <span class="prompt">C:\&gt;</span> <span class="cmd">ping 10.10.2.20</span> <span class="success">→ Reply (IP still works!)</span><br><br>
      <span class="comment">## Key insight: DNS is a dependency — without it, name-based</span><br>
      <span class="comment">## access fails even though the network path is fine.</span>
    </div>
    <h3>Monitoring Dashboard &amp; Alerts</h3>
    <p>An <strong>Azure Portal Dashboard</strong> is deployed with real-time metric charts for the DNS and Web servers. Open it in Azure Portal → Dashboards → <code>MIT565-Chaos-Engineering-Dashboard</code> to watch metrics change live during experiments.</p>
    <table>
      <tr><th>Dashboard Tile</th><th>What It Shows</th><th>During Outage</th></tr>
      <tr><td>DNS Server CPU %</td><td>Real-time CPU utilization</td><td class="deny">Drops to 0%</td></tr>
      <tr><td>DNS Server Network</td><td>Bytes in/out per minute</td><td class="deny">Flatlines to 0</td></tr>
      <tr><td>Web Server CPU %</td><td>Real-time CPU utilization</td><td class="deny">Drops to 0%</td></tr>
      <tr><td>Web Server Network</td><td>Bytes in/out per minute</td><td class="deny">Flatlines to 0</td></tr>
    </table>
    <p><strong>Metric Alerts</strong> are configured to fire when server CPU drops below 1%. Check Azure Portal → Monitor → Alerts to see them trigger during experiments.</p>
  </div>

</div>

<div class="footer">
  <p>MIT 565 - Internetworking | Elmhurst University MCIT Program</p>
  <p>Deployed with Terraform on Microsoft Azure</p>
</div>

</body>
</html>
HTML
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  WEB SERVER – IIS at HQ (Branch 1, IT Subnet)                             ║
# ║  Static IP 10.10.2.20 – demonstrates HTTP/web services over TCP/IP        ║
# ║  Hosts a documentation website for the MIT 565 Azure Lab project          ║
# ║                                                                           ║
# ║  Concepts demonstrated:                                                   ║
# ║    - Application Layer (HTTP/HTTPS) in the TCP/IP stack                   ║
# ║    - DNS A record resolution → web server IP                              ║
# ║    - NSG rules allowing/blocking HTTP traffic (port 80)                   ║
# ║    - Routing from client subnets to server subnet                         ║ 
# ║    - End-to-end: DNS lookup → ARP → routing → TCP → HTTP response         ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

module "web_server" {
  count               = var.deploy_web_server ? 1 : 0
  source              = "./modules/windows-server"
  resource_group_name = azurerm_resource_group.branch1.name
  region              = var.region_1
  subnet_id           = module.network_branch1.it_subnet_id
  vm_name             = "web-server"
  vm_size             = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  private_ip_address  = "10.10.2.20"
  install_iis         = true
  dns_servers         = ["10.10.2.10"]
  iis_content_url     = azurerm_storage_blob.website_html[0].url
  use_spot            = var.use_spot
  tags                = var.tags

  depends_on = [module.network_branch1]
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  PHASE 9: CHAOS STUDIO – Resilience & Fault Injection Testing             ║
# ║  Demonstrates: Chaos engineering, failure testing, incident response      ║
# ║  Cisco equivalent: Pulling cables, shutting interfaces, ACL mistakes      ║
# ║                                                                           ║
# ║  Experiments:                                                             ║
# ║    1. DNS Outage – shut down DNS server → name resolution fails           ║
# ║    2. Web Server Outage – shut down IIS → website unreachable             ║
# ║    3. Network Partition – deny-all NSG on HR → subnet isolated            ║
# ║                                                                           ║
# ║  Students start experiments from Azure Portal → Chaos Studio              ║
# ║  Toggle: var.deploy_chaos in terraform.tfvars                             ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ── Chaos Targets: Enable Chaos Studio on VMs and NSGs ─────────────────────

resource "azurerm_chaos_studio_target" "dns_server" {
  count              = var.deploy_chaos && var.deploy_dns ? 1 : 0
  location           = var.region_1
  target_resource_id = module.dns_server[0].vm_id
  target_type        = "Microsoft-VirtualMachine"
}

resource "azurerm_chaos_studio_target" "web_server" {
  count              = var.deploy_chaos && var.deploy_web_server ? 1 : 0
  location           = var.region_1
  target_resource_id = module.web_server[0].vm_id
  target_type        = "Microsoft-VirtualMachine"
}

resource "azurerm_chaos_studio_target" "hr_nsg_branch1" {
  count              = var.deploy_chaos && var.deploy_nsgs ? 1 : 0
  location           = var.region_1
  target_resource_id = module.nsg_branch1[0].hr_nsg_id
  target_type        = "Microsoft-NetworkSecurityGroup"
}

# ── Chaos Capabilities: What faults can be injected ────────────────────────

resource "azurerm_chaos_studio_capability" "dns_shutdown" {
  count                  = var.deploy_chaos && var.deploy_dns ? 1 : 0
  chaos_studio_target_id = azurerm_chaos_studio_target.dns_server[0].id
  capability_type        = "Shutdown-1.0"
}

resource "azurerm_chaos_studio_capability" "web_shutdown" {
  count                  = var.deploy_chaos && var.deploy_web_server ? 1 : 0
  chaos_studio_target_id = azurerm_chaos_studio_target.web_server[0].id
  capability_type        = "Shutdown-1.0"
}

resource "azurerm_chaos_studio_capability" "hr_nsg_rule" {
  count                  = var.deploy_chaos && var.deploy_nsgs ? 1 : 0
  chaos_studio_target_id = azurerm_chaos_studio_target.hr_nsg_branch1[0].id
  capability_type        = "SecurityRule-1.0"
}

# ── Experiment 1: DNS Server Outage ───────────────────────────────────────
# Shuts down the DNS server for 5 minutes.
# Students observe: nslookup fails, but ping by IP still works.
# Teaches: DNS is a single point of failure; redundancy matters.
# Cisco equivalent: shutting the DNS server's interface

resource "azurerm_chaos_studio_experiment" "dns_outage" {
  count               = var.deploy_chaos && var.deploy_dns ? 1 : 0
  location            = var.region_1
  name                = "chaos-dns-outage"
  resource_group_name = azurerm_resource_group.branch1.name

  identity {
    type = "SystemAssigned"
  }

  selectors {
    name                    = "dns-server-target"
    chaos_studio_target_ids = [azurerm_chaos_studio_target.dns_server[0].id]
  }

  steps {
    name = "shutdown-dns"
    branch {
      name = "main"
      actions {
        action_type   = "continuous"
        duration      = "PT5M"
        urn           = azurerm_chaos_studio_capability.dns_shutdown[0].urn
        selector_name = "dns-server-target"
        parameters = {
          abruptShutdown = "false"
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "chaos_dns_contributor" {
  count                = var.deploy_chaos && var.deploy_dns ? 1 : 0
  scope                = module.dns_server[0].vm_id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_chaos_studio_experiment.dns_outage[0].identity[0].principal_id
}

# ── Experiment 2: Web Server Outage ───────────────────────────────────────
# Shuts down the IIS web server for 5 minutes.
# Students observe: HTTP requests fail, but DNS still resolves the name.
# Teaches: Application-layer vs network-layer failures.
# Cisco equivalent: shutting the web server's interface

resource "azurerm_chaos_studio_experiment" "web_outage" {
  count               = var.deploy_chaos && var.deploy_web_server ? 1 : 0
  location            = var.region_1
  name                = "chaos-web-outage"
  resource_group_name = azurerm_resource_group.branch1.name

  identity {
    type = "SystemAssigned"
  }

  selectors {
    name                    = "web-server-target"
    chaos_studio_target_ids = [azurerm_chaos_studio_target.web_server[0].id]
  }

  steps {
    name = "shutdown-web"
    branch {
      name = "main"
      actions {
        action_type   = "continuous"
        duration      = "PT5M"
        urn           = azurerm_chaos_studio_capability.web_shutdown[0].urn
        selector_name = "web-server-target"
        parameters = {
          abruptShutdown = "false"
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "chaos_web_contributor" {
  count                = var.deploy_chaos && var.deploy_web_server ? 1 : 0
  scope                = module.web_server[0].vm_id
  role_definition_name = "Virtual Machine Contributor"
  principal_id         = azurerm_chaos_studio_experiment.web_outage[0].identity[0].principal_id
}

# ── Experiment 3: HR Network Partition ────────────────────────────────────
# Injects a deny-all inbound NSG rule on the HR subnet for 5 minutes.
# Students observe: HR VM is completely isolated — no ping, no RDP, no HTTP.
# Teaches: ACL/firewall misconfiguration impact, incident response.
# Cisco equivalent: applying "deny ip any any" on an interface

resource "azurerm_chaos_studio_experiment" "network_partition" {
  count               = var.deploy_chaos && var.deploy_nsgs ? 1 : 0
  location            = var.region_1
  name                = "chaos-hr-network-partition"
  resource_group_name = azurerm_resource_group.branch1.name

  identity {
    type = "SystemAssigned"
  }

  selectors {
    name                    = "hr-nsg-target"
    chaos_studio_target_ids = [azurerm_chaos_studio_target.hr_nsg_branch1[0].id]
  }

  steps {
    name = "inject-deny-all"
    branch {
      name = "main"
      actions {
        action_type   = "continuous"
        duration      = "PT5M"
        urn           = azurerm_chaos_studio_capability.hr_nsg_rule[0].urn
        selector_name = "hr-nsg-target"
        parameters = {
          direction             = "Inbound"
          sourceAddresses       = "[\"*\"]"
          destinationAddresses  = "[\"*\"]"
          sourcePortRanges      = "[\"*\"]"
          destinationPortRanges = "[\"*\"]"
          protocols             = "[\"*\"]"
          access                = "Deny"
          priority              = "10"
          name                  = "chaos-deny-all-inbound"
        }
      }
    }
  }
}

resource "azurerm_role_assignment" "chaos_nsg_contributor" {
  count                = var.deploy_chaos && var.deploy_nsgs ? 1 : 0
  scope                = module.nsg_branch1[0].hr_nsg_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_chaos_studio_experiment.network_partition[0].identity[0].principal_id
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  CHAOS STUDIO – Monitoring Dashboard & Alerts                             ║
# ║  Azure Portal dashboard with real-time VM metrics + metric alerts         ║
# ║  Students watch metrics change in real-time during chaos experiments      ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

# ── Log Analytics Workspace (enables VM metric collection) ─────────────────

resource "azurerm_log_analytics_workspace" "chaos" {
  count               = var.deploy_chaos ? 1 : 0
  name                = "log-mit565-chaos"
  location            = var.region_1
  resource_group_name = azurerm_resource_group.branch1.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

# ── Action Group (alert notification target) ──────────────────────────────

resource "azurerm_monitor_action_group" "chaos_alerts" {
  count               = var.deploy_chaos ? 1 : 0
  name                = "ag-chaos-alerts"
  resource_group_name = azurerm_resource_group.branch1.name
  short_name          = "ChaosAlert"
  tags                = var.tags
}

# ── Metric Alert: DNS Server Down ─────────────────────────────────────────
# Fires when DNS server CPU drops below 1% for 1 minute (VM shutting down)
# Triggers during chaos-dns-outage experiment

resource "azurerm_monitor_metric_alert" "dns_server_down" {
  count               = var.deploy_chaos && var.deploy_dns ? 1 : 0
  name                = "alert-dns-server-down"
  resource_group_name = azurerm_resource_group.branch1.name
  scopes              = [module.dns_server[0].vm_id]
  description         = "DNS Server CPU dropped below 1% — server may be down (Chaos Studio experiment)"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.chaos_alerts[0].id
  }
}

# ── Metric Alert: Web Server Down ─────────────────────────────────────────

resource "azurerm_monitor_metric_alert" "web_server_down" {
  count               = var.deploy_chaos && var.deploy_web_server ? 1 : 0
  name                = "alert-web-server-down"
  resource_group_name = azurerm_resource_group.branch1.name
  scopes              = [module.web_server[0].vm_id]
  description         = "Web Server CPU dropped below 1% — server may be down (Chaos Studio experiment)"
  severity            = 1
  frequency           = "PT1M"
  window_size         = "PT5M"
  tags                = var.tags

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "LessThan"
    threshold        = 1
  }

  action {
    action_group_id = azurerm_monitor_action_group.chaos_alerts[0].id
  }
}

# ── Azure Portal Dashboard – Chaos Engineering Monitoring ───────────────
# Real-time metric tiles for VM CPU, network, and experiment instructions
# Students open this dashboard in Azure Portal during chaos experiments

resource "azurerm_portal_dashboard" "chaos_monitoring" {
  count                = var.deploy_chaos && var.deploy_dns && var.deploy_web_server ? 1 : 0
  name                 = "MIT565-Chaos-Engineering-Dashboard"
  resource_group_name  = azurerm_resource_group.branch1.name
  location             = var.region_1
  tags                 = var.tags
  dashboard_properties = jsonencode({
    lenses = {
      "0" = {
        order = 0
        parts = {
          # ── Row 0: Dashboard Header ──────────────────────────────
          "0" = {
            position = { x = 0, y = 0, colSpan = 12, rowSpan = 3 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = "## 🔥 MIT 565 – Chaos Engineering Dashboard\n\nMonitor infrastructure health during **Azure Chaos Studio** experiments. Watch metrics change in real-time as faults are injected.\n\n| Experiment | Target | Duration | What to Watch |\n|---|---|---|---|\n| `chaos-dns-outage` | DNS Server (10.10.2.10) | 5 min | CPU drops to 0%, Network flatlines |\n| `chaos-web-outage` | Web Server (10.10.2.20) | 5 min | CPU drops to 0%, Network flatlines |\n| `chaos-hr-network-partition` | HR NSG | 5 min | HR VM loses all connectivity |\n\n**To start:** Chaos Studio → Experiments → Select → Start"
                    title    = ""
                    subtitle = ""
                  }
                }
              }
            }
          }
          # ── Row 3: DNS Server CPU % ─────────────────────────────
          "1" = {
            position = { x = 0, y = 3, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                },
                {
                  name       = "options"
                  isOptional = true
                  value = {
                    chart = {
                      metrics = [
                        {
                          resourceMetadata = {
                            id = module.dns_server[0].vm_id
                          }
                          name            = "Percentage CPU"
                          aggregationType = 4
                          namespace       = "microsoft.compute/virtualmachines"
                          metricVisualization = {
                            displayName         = "CPU %"
                            resourceDisplayName = "dns-server"
                            color               = "#00BCF2"
                          }
                        }
                      ]
                      title    = "DNS Server – CPU % (drops to 0 during outage)"
                      titleKind = 1
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true, axisType = 2 }
                          y = { isVisible = true, axisType = 1 }
                        }
                      }
                      timespan = {
                        relative  = { duration = 3600000 }
                        showUTCTime = false
                        grain     = 1
                      }
                    }
                  }
                }
              ]
              settings = {}
            }
          }
          # ── Row 3: DNS Server Network ──────────────────────────
          "2" = {
            position = { x = 6, y = 3, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                },
                {
                  name       = "options"
                  isOptional = true
                  value = {
                    chart = {
                      metrics = [
                        {
                          resourceMetadata = {
                            id = module.dns_server[0].vm_id
                          }
                          name            = "Network In Total"
                          aggregationType = 1
                          namespace       = "microsoft.compute/virtualmachines"
                          metricVisualization = {
                            displayName         = "Network In"
                            resourceDisplayName = "dns-server"
                            color               = "#44F1C6"
                          }
                        },
                        {
                          resourceMetadata = {
                            id = module.dns_server[0].vm_id
                          }
                          name            = "Network Out Total"
                          aggregationType = 1
                          namespace       = "microsoft.compute/virtualmachines"
                          metricVisualization = {
                            displayName         = "Network Out"
                            resourceDisplayName = "dns-server"
                            color               = "#EB9371"
                          }
                        }
                      ]
                      title    = "DNS Server – Network In/Out (flatlines during outage)"
                      titleKind = 1
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true, axisType = 2 }
                          y = { isVisible = true, axisType = 1 }
                        }
                      }
                      timespan = {
                        relative  = { duration = 3600000 }
                        showUTCTime = false
                        grain     = 1
                      }
                    }
                  }
                }
              ]
              settings = {}
            }
          }
          # ── Row 7: Web Server CPU % ─────────────────────────────
          "3" = {
            position = { x = 0, y = 7, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                },
                {
                  name       = "options"
                  isOptional = true
                  value = {
                    chart = {
                      metrics = [
                        {
                          resourceMetadata = {
                            id = module.web_server[0].vm_id
                          }
                          name            = "Percentage CPU"
                          aggregationType = 4
                          namespace       = "microsoft.compute/virtualmachines"
                          metricVisualization = {
                            displayName         = "CPU %"
                            resourceDisplayName = "web-server"
                            color               = "#FFB900"
                          }
                        }
                      ]
                      title    = "Web Server – CPU % (drops to 0 during outage)"
                      titleKind = 1
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true, axisType = 2 }
                          y = { isVisible = true, axisType = 1 }
                        }
                      }
                      timespan = {
                        relative  = { duration = 3600000 }
                        showUTCTime = false
                        grain     = 1
                      }
                    }
                  }
                }
              ]
              settings = {}
            }
          }
          # ── Row 7: Web Server Network ──────────────────────────
          "4" = {
            position = { x = 6, y = 7, colSpan = 6, rowSpan = 4 }
            metadata = {
              type = "Extension/HubsExtension/PartType/MonitorChartPart"
              inputs = [
                {
                  name       = "sharedTimeRange"
                  isOptional = true
                },
                {
                  name       = "options"
                  isOptional = true
                  value = {
                    chart = {
                      metrics = [
                        {
                          resourceMetadata = {
                            id = module.web_server[0].vm_id
                          }
                          name            = "Network In Total"
                          aggregationType = 1
                          namespace       = "microsoft.compute/virtualmachines"
                          metricVisualization = {
                            displayName         = "Network In"
                            resourceDisplayName = "web-server"
                            color               = "#44F1C6"
                          }
                        },
                        {
                          resourceMetadata = {
                            id = module.web_server[0].vm_id
                          }
                          name            = "Network Out Total"
                          aggregationType = 1
                          namespace       = "microsoft.compute/virtualmachines"
                          metricVisualization = {
                            displayName         = "Network Out"
                            resourceDisplayName = "web-server"
                            color               = "#EB9371"
                          }
                        }
                      ]
                      title    = "Web Server – Network In/Out (flatlines during outage)"
                      titleKind = 1
                      visualization = {
                        chartType = 2
                        legendVisualization = {
                          isVisible    = true
                          position     = 2
                          hideSubtitle = false
                        }
                        axisVisualization = {
                          x = { isVisible = true, axisType = 2 }
                          y = { isVisible = true, axisType = 1 }
                        }
                      }
                      timespan = {
                        relative  = { duration = 3600000 }
                        showUTCTime = false
                        grain     = 1
                      }
                    }
                  }
                }
              ]
              settings = {}
            }
          }
          # ── Row 11: Experiment Guide ────────────────────────────
          "5" = {
            position = { x = 0, y = 11, colSpan = 6, rowSpan = 6 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = "## 📋 How to Run an Experiment\n\n1. **Open Chaos Studio** in Azure Portal\n2. Click **Experiments** in the left menu\n3. Select an experiment:\n   - `chaos-dns-outage` – Shuts down DNS server\n   - `chaos-web-outage` – Shuts down web server\n   - `chaos-hr-network-partition` – Isolates HR subnet\n4. Click **Start** → **Yes** to confirm\n5. **Watch this dashboard** – metrics change within 30-60 seconds\n6. After **5 minutes**, the fault auto-reverts\n\n### 🔔 Alerts\n\nMetric alerts fire when DNS or Web server CPU drops below 1%.\nCheck **Alerts** in Azure Monitor to see them trigger."
                    title    = ""
                    subtitle = ""
                  }
                }
              }
            }
          }
          # ── Row 11: Monitoring Checklist ────────────────────────
          "6" = {
            position = { x = 6, y = 11, colSpan = 6, rowSpan = 6 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = "## 🔍 Monitoring Checklist\n\n### During DNS Outage\n- [ ] DNS Server CPU % → drops to 0%\n- [ ] DNS Server Network → flatlines\n- [ ] `nslookup` from client VM → TIMEOUT\n- [ ] `ping 10.10.2.20` (by IP) → still works\n- [ ] Alert fires in Azure Monitor\n\n### During Web Server Outage\n- [ ] Web Server CPU % → drops to 0%\n- [ ] Web Server Network → flatlines\n- [ ] `curl http://web-server.mit565.local` → fails\n- [ ] `nslookup web-server.mit565.local` → still resolves\n- [ ] Alert fires in Azure Monitor\n\n### During HR Network Partition\n- [ ] From HR VM: `ping 10.10.2.10` → TIMEOUT\n- [ ] From IT VM: `ping 10.10.0.x` → TIMEOUT\n- [ ] From Finance VM: all access → still works\n- [ ] After 5 min: HR connectivity restores"
                    title    = ""
                    subtitle = ""
                  }
                }
              }
            }
          }
          # ── Row 17: Cisco Comparison ────────────────────────────
          "7" = {
            position = { x = 0, y = 17, colSpan = 12, rowSpan = 4 }
            metadata = {
              type   = "Extension/HubsExtension/PartType/MarkdownPart"
              inputs = []
              settings = {
                content = {
                  settings = {
                    content  = "## 🔄 Cisco Equivalent Mapping\n\n| Chaos Experiment | What It Simulates | Cisco Equivalent | Key Lesson |\n|---|---|---|---|\n| DNS Outage | DNS server failure | `shutdown` on DNS server interface | DNS is a critical dependency — without it, name-based access fails even if the network is fine |\n| Web Server Outage | Application failure | `shutdown` on web server interface | Network-layer vs application-layer failures — the path works but the service is down |\n| HR Network Partition | ACL misconfiguration | `deny ip any any` applied to interface | A single bad ACL rule can completely isolate a subnet — always have out-of-band access |\n\n**Key takeaway:** These experiments prove that infrastructure failures happen — monitoring, alerting, and redundancy are essential networking skills."
                    title    = ""
                    subtitle = ""
                  }
                }
              }
            }
          }
        }
      }
    }
    metadata = {
      model = {
        timeRange = {
          value = {
            relative = {
              duration = 1
              timeUnit = 1
            }
          }
          type = "MsPortalFx.Composition.Configuration.ValueTypes.TimeRange"
        }
        filterLocale = {
          value = "en-us"
        }
      }
    }
  })
}