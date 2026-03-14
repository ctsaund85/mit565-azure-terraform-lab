# Changelog

All notable changes to the MIT 565 Internetworking Azure Lab.

---

## [2.2.0] – 2026-03-13

### VPN Gateway Reliability Improvements
- **Fixed** VPN gateway destroy failures caused by gateways stuck in "Failed" state. Added a destroy-time `local-exec` provisioner that pre-deletes the gateway via Azure CLI before Terraform's own delete. Handles Failed-state gateways gracefully (`on_failure = continue`).
- **Fixed** parallel VPN gateway provisioning failures. Added `vpn_gateway_depends_on_id` variable to the hub-spoke-vnet module that serializes gateway creation — Branch 2's gateway now waits for Branch 1 to finish. Prevents Azure from failing when two `VpnGw1` gateways provision simultaneously.
- **Added** 60-minute `timeouts` block (create/update/delete) on VPN gateway resources to prevent premature Terraform cancellation during long provisioning operations.

### Code Quality Fixes
- **Added** `required_providers` block with version pinning (`azurerm ~> 4.0`, Terraform `>= 1.5`) to prevent breaking changes from untested provider upgrades.
- **Fixed** unreliable DNS A records for client VMs. Removed hardcoded `branch1-client` and `branch2-client` records that assumed specific dynamic IPs. Client VMs auto-register via `registration_enabled = true` on the Private DNS zone VNet links.

### Testing
- **Validated** all 9 phases with comprehensive testing:
  - Incremental apply (Phase 1→9): All passed
  - Incremental destroy (Phase 9→1): All passed
  - All-at-once apply/destroy (117 resources): Both passed
  - Combo tests (partial phase sets): Both passed

---

## [2.1.0] – 2026-03-07

### New Feature: Azure Chaos Studio (Phase 9)

#### Chaos Studio Experiments
- **Added** `deploy_chaos` boolean variable (Phase 9 toggle) for Azure Chaos Studio
- **Added** 3 Chaos Studio experiments for fault injection testing:
  - `chaos-dns-outage` – Gracefully shuts down the DNS server VM for 5 minutes. Students observe: nslookup fails, ping by IP still works. Teaches DNS dependency and single points of failure.
  - `chaos-web-outage` – Gracefully shuts down the IIS web server VM for 5 minutes. Students observe: HTTP fails, DNS still resolves the name. Teaches application-layer vs network-layer failures.
  - `chaos-hr-network-partition` – Injects a deny-all inbound NSG rule on the HR subnet for 5 minutes. Students observe: HR VM completely isolated. Teaches ACL misconfiguration impact.
- **Added** Chaos Studio targets on DNS server VM, web server VM, and HR NSG (Branch 1)
- **Added** Chaos Studio capabilities: `Shutdown-1.0` (VMs), `SecurityRule-1.0` (NSG)
- **Added** Role assignments: Virtual Machine Contributor (VM experiments), Network Contributor (NSG experiment)
- Each experiment conditionally deploys based on its prerequisite phase (DNS, web server, or NSGs)
- Cisco equivalent: pulling cables (`shutdown`), applying `deny ip any any` on an interface

#### Monitoring Dashboard & Alerts
- **Added** Azure Portal Dashboard (`MIT565-Chaos-Engineering-Dashboard`) with 8 real-time tiles:
  - Markdown header with experiment overview table
  - DNS Server CPU % line chart (drops to 0% during `chaos-dns-outage`)
  - DNS Server Network In/Out line chart (flatlines during outage)
  - Web Server CPU % line chart (drops to 0% during `chaos-web-outage`)
  - Web Server Network In/Out line chart (flatlines during outage)
  - Experiment Guide markdown (step-by-step instructions)
  - Monitoring Checklist markdown (what to verify during each experiment)
  - Cisco Comparison markdown (experiment-to-CLI mapping)
- **Added** Log Analytics Workspace (`log-mit565-chaos`) – PerGB2018 SKU, 30-day retention
- **Added** Azure Monitor Action Group (`ag-chaos-alerts`) – alert notification target
- **Added** Metric Alert: `alert-dns-server-down` – fires when DNS server CPU < 1% (5-min window, severity 1)
- **Added** Metric Alert: `alert-web-server-down` – fires when web server CPU < 1% (5-min window, severity 1)
- Dashboard conditionally deploys when `deploy_chaos`, `deploy_dns`, and `deploy_web_server` are all enabled

#### Documentation Updates
- **Added** Chaos Studio section to IIS website HTML with experiment table, how-to guide, and lab exercise
- **Added** Monitoring Dashboard & Alerts subsection to IIS website with tile table and alert descriptions
- **Added** Chaos Engineering card in website overview concept grid
- **Added** "Chaos/Failure Testing" row in Cisco→Azure concept mapping table (website + README)
- **Added** Phase 9 deployment guide in README with dashboard tiles table, metric alerts docs, and how-to-open-dashboard instructions
- **Added** Lab 11: Chaos Engineering (Failure Testing) in README with dashboard setup steps, experiment exercises with dashboard monitoring, and 5 discussion questions
- **Updated** README: TOC, overview, cost estimate, initial setup toggles, variables reference, troubleshooting table (including dashboard/alerts entries)
- **Updated** CHANGELOG (this entry)

---

## [2.0.0] – 2026-03-07

### Major Changes

#### Null Routes (Blackhole UDRs) – Defense in Depth
- **Added** null routes (`next_hop_type = "None"`) between HR↔Finance subnets on both branches
  - HR route table: drops all traffic destined for Finance subnet
  - Finance route table: drops all traffic destined for HR subnet
  - IT route table: no blocking routes (admin access preserved)
- Route tables now accept `hr_subnet_prefix` and `finance_subnet_prefix` variables for the null route destinations
- Creates **defense in depth** with NSGs — traffic blocked at both Layer 3 (routing) and Layer 4 (ACLs)
- Cisco equivalent: `ip route 10.x.1.0 255.255.255.0 Null0`

#### NAT Gateway on Branch 2
- **Changed** Branch 2 from `nat_gateway_enabled = false` to `var.nat_gateway_enabled` (tracks the Phase 2 toggle)
- Both branches now get their own NAT Gateway for outbound internet access (SNAT)
- Each branch shows a different public IP on IP Chicken — demonstrates PAT per-site

#### IIS Website Documentation Overhaul
- **Rewritten** routing section documenting null routes, defense-in-depth concept, and NAT Gateway on both branches
- **Added** null route table showing HR→Finance DROP, Finance→HR DROP, IT ALLOW ALL with Cisco equivalents
- **Added** Management Access section documenting Bastion (browser + native client) and Branch 2 RDP-over-VPN workflow
- **Updated** Lab Exercise #4 (Routing Tables) with null route testing, defense-in-depth walkthrough
- **Updated** Concept Mapping table: Static Routing → "Null routes (blackhole) between HR↔Finance"
- **Updated** NAT row: "NAT Gateway on both branches (outbound internet)"
- **Updated** IaC module table: route-tables → "Route tables with null routes (HR↔Finance blackhole) + BGP propagation"
- **Fixed** BGP ASN values from incorrect 65001/65002 to correct 65010/65020
- **Fixed** routing section that incorrectly said "Branch 2 uses Azure built-in routing"

#### Documentation
- **Added** comprehensive README.md with:
  - Complete phase-by-phase deployment guide (for professors/instructors)
  - 10 detailed lab exercises with commands, expected output, and discussion questions
  - Network architecture diagram and IP addressing scheme
  - Cisco-to-Azure concept mapping table
  - Cost estimates and cost control recommendations
  - Troubleshooting guide
  - Variables reference table
- **Added** CHANGELOG.md (this file)

### Files Changed
- `modules/route-tables/main.tf` – Added null routes (HR↔Finance blackhole), updated comments
- `modules/route-tables/variables.tf` – Added `hr_subnet_prefix`, `finance_subnet_prefix` variables
- `main.tf` – Branch 2 NAT GW enabled, subnet prefixes passed to route modules, topology diagram updated, IIS HTML updated
- `README.md` – Created
- `CHANGELOG.md` – Created

---

## [1.5.0] – 2026-03-07

### Enhancements

#### Spot VM Toggle
- **Added** `use_spot` boolean variable to all VM modules (windows-server, windows-clients)
- When `true`: VMs use Spot pricing (priority = "Spot", eviction_policy = "Deallocate", max_bid_price = -1)
- When `false` (default): VMs use regular pricing
- Saves 60-90% on VM costs for lab/dev workloads

#### Resource Tagging
- **Added** `tags` variable (map(string)) to all modules and resources
- Tags propagated from root `terraform.tfvars` through every module
- Default tags: project, course, university, environment, deployed_by

#### BGInfo Extension
- **Added** BGInfo VM extension to all Windows Server and Client VMs
- Displays system info (IP, hostname, OS, memory) on desktop wallpaper
- Note: BGInfo wallpaper not visible via Bastion browser RDP — use native client

#### Desktop Shortcuts
- **Added** DNS Manager shortcut on dns-server VM
- **Added** IIS Manager shortcut on web-server VM
- **Added** IP Chicken (ipchicken.com) shortcut on ALL VMs — verifies NAT Gateway public IP

#### Azure Bastion Tunneling
- **Added** `tunneling_enabled = true` on Bastion host (Standard SKU)
- Enables native RDP client connections via `az network bastion tunnel` command
- Better experience than browser-based RDP (supports wallpaper, copy/paste, multi-monitor)

### Files Changed
- `variables.tf` – Added `use_spot`, `tags` variables
- `terraform.tfvars` – Added `use_spot = false`, `tags` block
- `modules/windows-server/main.tf` – Spot VM support, BGInfo extension, desktop shortcuts, tags
- `modules/windows-server/variables.tf` – Added `use_spot`, `tags` variables
- `modules/windows-clients/main.tf` – Spot VM support, BGInfo extension, IP Chicken shortcut, tags
- `modules/windows-clients/variables.tf` – Added `use_spot`, `tags` variables
- `modules/hub-spoke-vnet/main.tf` – Tags, `tunneling_enabled = true` on Bastion
- `modules/hub-spoke-vnet/variables.tf` – Added `tags` variable
- `modules/nsg/main.tf` – Tags on all NSGs
- `modules/nsg/variables.tf` – Added `tags` variable
- `modules/route-tables/main.tf` – Tags on all route tables
- `modules/route-tables/variables.tf` – Added `tags` variable
- `modules/dns/main.tf` – Tags on DNS zone
- `modules/dns/variables.tf` – Added `tags` variable
- `main.tf` – Tags on resource groups, VPN connections, storage account; use_spot/tags passed to all modules

---

## [1.4.0] – 2026-03-07

### Bug Fixes

#### BGP Route Propagation
- **Fixed** `bgp_route_propagation_enabled` changed from `false` to `true` on all 6 route tables
- Previous setting blocked VPN gateway BGP learned routes from reaching spoke subnets
- Cross-branch connectivity (Branch 1 ↔ Branch 2) was broken when route tables were deployed
- Equivalent to: enabling OSPF/EIGRP on a VLAN interface that had only static routes

#### VNet Peering Depends-On
- **Fixed** VNet peering resources now have `depends_on = [azurerm_virtual_network_gateway.vpn_gateway]`
- Previously, `use_remote_gateways = true` could fail if peering was created before VPN gateway
- Ensures correct resource creation ordering

#### VM SKU Availability
- **Changed** default `vm_size` recommendation to `Standard_B2ms` (2 vCPU / 8 GB RAM)
- `Standard_B2s` had capacity exhaustion in centralus region
- B2ms is same price tier, more memory (8 GB vs 4 GB)

---

## [1.3.0] – 2026-03-06

### Features

#### Branch 2 Bastion Decision
- **Decided** to keep Bastion disabled on Branch 2 (simulates remote branch with no local management)
- Students RDP from Branch 1 VM to Branch 2 VMs via VPN — proves cross-branch connectivity

---

## [1.2.0] – 2026-03-06

### Major Changes

#### Firewall → NAT Gateway Migration
- **Removed** Azure Firewall (~$288/month) and replaced with NAT Gateway (~$32/month)
- NAT Gateway provides outbound SNAT without the cost of a full firewall
- Simplified routing — no more `0.0.0.0/0 → VirtualAppliance (firewall IP)` UDRs
- Route tables simplified to BGP propagation only (null routes added later in v2.0.0)

#### Phase Toggle System
- **Added** 7 boolean variables for incremental deployment:
  - `nat_gateway_enabled` (Phase 2)
  - `deploy_nsgs` (Phase 3)
  - `deploy_route_tables` (Phase 4)
  - `deploy_dns` (Phase 5)
  - `deploy_clients` (Phase 6)
  - `deploy_vpn` (Phase 7)
  - `deploy_web_server` (Phase 8)
- Phase 1 (Core Networking) always deploys
- Allows professors to build the network incrementally during class, one concept at a time

---

## [1.1.0] – 2026-03-05

### Features

#### IIS Documentation Website
- **Added** comprehensive HTML documentation website served by IIS on web-server VM
- Content stored as a Terraform heredoc in `main.tf`, uploaded to Azure Blob Storage, downloaded by IIS CustomScriptExtension
- Sections: Overview, Concept Mapping, Topology, IP Addressing, Security Rules, Routing, DNS, Lab Exercises, TCP/IP Stack, Infrastructure as Code

#### VPN Gateway with BGP
- **Added** VPN Gateways on both branches (VpnGw1 SKU, route-based)
- **Added** BGP with ASN 65010 (Branch 1) and 65020 (Branch 2)
- **Added** VNet-to-VNet connections with shared key authentication

---

## [1.0.0] – 2026-03-04

### Initial Release

#### Core Infrastructure
- Hub-Spoke VNet topology across 2 Azure regions (centralus, eastus2)
- 2 Hub VNets with GatewaySubnet and BastionSubnet
- 2 Spoke VNets with HR, Finance, IT department subnets
- VNet Peering (Hub↔Spoke) per branch
- Azure Bastion (Standard SKU) on Branch 1

#### Network Security Groups
- Per-department NSGs on both branches (6 total)
- IT: full access (admin VLAN)
- HR: allow ICMP/RDP from IT, deny RDP from Finance
- Finance: allow ICMP/RDP from IT, deny RDP from HR

#### Route Tables
- Per-department route tables on both branches (6 total)
- BGP route propagation for cross-branch connectivity

#### DNS
- Azure Private DNS zone: `mit565.local`
- A records for dns-server, web-server, branch1-client, branch2-client
- VNet links for cross-branch name resolution
- Windows DNS Server VM with DNS role and management tools

#### Virtual Machines
- dns-server (10.10.2.10) – Windows Server 2022, DNS role
- web-server (10.10.2.20) – Windows Server 2022, IIS role
- b1-hr-pc1 – Branch 1 HR workstation
- b1-fin-pc1 – Branch 1 Finance workstation
- b2-hr-pc1 – Branch 2 HR workstation
- All VMs: Windows Server 2022 Datacenter, Standard_B2s (later changed to B2ms)

#### Terraform Modules
- `hub-spoke-vnet` – Network topology with all services
- `nsg` – Network Security Groups
- `route-tables` – User-Defined Route tables
- `dns` – Azure Private DNS
- `windows-server` – DNS and Web server VMs
- `windows-clients` – Department workstations
