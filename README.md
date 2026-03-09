# MIT 565 – Internetworking Azure Lab

> **Elmhurst University — MCIT Program**
> A complete Azure cloud networking lab that demonstrates every core concept from MIT 565 Internetworking, mapped from physical Cisco equipment to Microsoft Azure infrastructure.

---

## Table of Contents

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Cost Estimate](#cost-estimate)
- [Quick Start](#quick-start)
- [Project Structure](#project-structure)
- [Network Architecture](#network-architecture)
- [Phase-by-Phase Deployment Guide](#phase-by-phase-deployment-guide)
  - [Phase 1: Core Networking](#phase-1-core-networking-always-on)
  - [Phase 2: NAT Gateway](#phase-2-nat-gateway)
  - [Phase 3: NSGs (ACLs)](#phase-3-nsgs-acls)
  - [Phase 4: Route Tables (UDRs)](#phase-4-route-tables-udrs)
  - [Phase 5: DNS](#phase-5-dns)
  - [Phase 6: Client VMs](#phase-6-client-vms)
  - [Phase 7: VPN Gateway (WAN/BGP)](#phase-7-vpn-gateway-wanbgp)
  - [Phase 8: Web Server (IIS)](#phase-8-web-server-iis)
  - [Phase 9: Chaos Studio](#phase-9-chaos-studio)
- [Concept Mapping: Cisco → Azure](#concept-mapping-cisco--azure)
- [Lab Exercises](#lab-exercises)
  - [Lab 1: IP Addressing & Subnetting](#lab-1-ip-addressing--subnetting)
  - [Lab 2: ARP & MAC Addresses](#lab-2-arp--mac-addresses)
  - [Lab 3: DNS Resolution](#lab-3-dns-resolution)
  - [Lab 4: Routing Tables & Null Routes (UDRs)](#lab-4-routing-tables--null-routes-udrs)
  - [Lab 5: NSG / ACL Testing](#lab-5-nsg--acl-testing)
  - [Lab 6: Defense in Depth (Routing + ACLs)](#lab-6-defense-in-depth-routing--acls)
  - [Lab 7: NAT & Outbound Internet](#lab-7-nat--outbound-internet)
  - [Lab 8: Cross-Branch VPN Connectivity](#lab-8-cross-branch-vpn-connectivity)
  - [Lab 9: Web Server (HTTP over TCP)](#lab-9-web-server-http-over-tcp)
  - [Lab 10: End-to-End TCP/IP Stack Walkthrough](#lab-10-end-to-end-tcpip-stack-walkthrough)
  - [Lab 11: Chaos Engineering (Failure Testing)](#lab-11-chaos-engineering-failure-testing)
- [Connecting to VMs](#connecting-to-vms)
- [Cost Controls](#cost-controls)
- [Tearing Down the Lab](#tearing-down-the-lab)
- [Troubleshooting](#troubleshooting)
- [Variables Reference](#variables-reference)

---

## Overview

This lab deploys a **hub-spoke network topology** across **two Azure regions** (simulating two branch offices) with:

- **VLANs → Subnets** — HR, Finance, and IT department isolation per branch
- **Trunk Links → VNet Peering** — Hub-to-Spoke connectivity
- **Static Routing → User-Defined Routes (UDRs)** — Null routes (blackhole) for department isolation
- **Dynamic Routing → BGP** — VPN Gateway with BGP for cross-branch route exchange
- **ACLs → Network Security Groups (NSGs)** — Per-department permit/deny rules
- **NAT → NAT Gateway** — Outbound SNAT on both branches
- **DNS → Azure Private DNS + Windows DNS Server** — Name resolution with nslookup
- **WAN Links → VPN Gateway Connections** — Site-to-site VPN between branches
- **Bastion → Azure Bastion** — Secure RDP without public IPs on VMs
- **Failure Testing → Azure Chaos Studio** — Controlled fault injection (server shutdown, NSG deny-all)

The entire lab is controlled by **9 phase toggles** in `terraform.tfvars`, allowing incremental deployment during class demonstrations.

---

## Prerequisites

| Requirement | Details |
|---|---|
| **Azure Subscription** | Student, Pay-As-You-Go, or Enterprise with permissions to create resource groups, VNets, VMs, and VPN Gateways |
| **Terraform** | v1.5+ ([install guide](https://developer.hashicorp.com/terraform/install)) |
| **Azure CLI** | v2.50+ ([install guide](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)) — needed for Bastion tunneling and authentication |
| **Remote Desktop Client** | macOS: Microsoft Remote Desktop from App Store. Windows: built-in `mstsc`. |

### First-Time Azure CLI Setup

```bash
# Login to Azure
az login

# Verify your subscription
az account show --query "{name:name, id:id}" -o table

# If you have multiple subscriptions, set the correct one:
az account set --subscription "YOUR_SUBSCRIPTION_ID"
```

### First-Time Terraform Setup

```bash
# Navigate to the lab directory
cd "Azure Terraform Lab"

# Initialize Terraform (downloads Azure provider)
terraform init
```

---

## Cost Estimate

| Resource | Per-Hour | Per-Day (8hr) | Notes |
|---|---|---|---|
| VMs (5x Standard_B2ms) | ~$0.42 | ~$3.36 | Deallocated VMs = $0. Spot VMs save 60-90% |
| VPN Gateways (2x VpnGw1) | ~$0.25 | ~$2.00 | Runs 24/7 while deployed |
| NAT Gateways (2x Standard) | ~$0.09 | ~$0.72 | Runs 24/7 while deployed |
| Azure Bastion (Standard) | ~$0.26 | ~$2.08 | Runs 24/7 while deployed |
| Chaos Studio | — | ~$0.50/run | $0.10/experiment-minute, only when running |
| **Total (full lab)** | **~$1.02** | **~$8.16** | |

> **Cost tip:** Always run `terraform destroy` when done. VPN Gateways and Bastion are the most expensive resources and run 24/7 even when VMs are stopped. For budget-constrained classes, enable Phase 7 (VPN) only when demonstrating WAN/BGP concepts.

---

## Quick Start

**Deploy everything at once (all phases enabled):**

```bash
cd "Azure Terraform Lab"
terraform init
terraform apply
```

**Deploy incrementally (recommended for class demos):**

1. Edit `terraform.tfvars` — set all phases to `false` except what you need
2. Run `terraform apply`
3. Enable the next phase, run `terraform apply` again
4. Repeat through all 8 phases

**Tear down when done:**

```bash
terraform destroy
```

---

## Project Structure

```
Azure Terraform Lab/
├── main.tf                  # Root orchestration — all modules, VPN connections, IIS website HTML
├── variables.tf             # Input variables — phase toggles, VM size, credentials
├── terraform.tfvars         # YOUR values — passwords, phase toggles, tags (DO NOT commit)
├── outputs.tf               # Useful outputs — IPs, VNet IDs, DNS zone name
├── provider.tf              # Azure provider configuration
│
├── modules/
│   ├── hub-spoke-vnet/      # Hub-Spoke VNets, subnets, peering, Bastion, NAT GW, VPN GW
│   ├── nsg/                 # Network Security Groups (ACLs) per department
│   ├── route-tables/        # Route tables with null routes (HR↔Finance blackhole)
│   ├── dns/                 # Azure Private DNS zone, A records, VNet links
│   ├── windows-server/      # Windows Server VMs (DNS server, IIS web server)
│   └── windows-clients/     # Windows client VMs (department workstations)
```

---

## Network Architecture

```
    Branch 1 (HQ) – Central US                    Branch 2 – East US 2

    +========================+                     +========================+
    |   Hub VNet 10.0.0.0/16 |                     |  Hub VNet 10.1.0.0/16  |
    |   +------------------+ |    VPN Tunnel       |  +------------------+  |
    |   | GatewaySubnet    |=|======(BGP)==========|==| GatewaySubnet    |  |
    |   | 10.0.1.0/27      | |    ASN 65010        |  | 10.1.1.0/27      |  |
    |   +------------------+ |         ↕           |  +------------------+  |
    |   | BastionSubnet    | |    ASN 65020        |                        |
    |   | 10.0.2.0/27      | |                     +===========+============+
    |   +------------------+ |                                 |
    +=========+=============++                          VNet Peering
              |                                                |
       VNet Peering                                +==========+==============+
              |                                    | Spoke VNet 10.20.0.0/16 |
    +==========+==============+                    |  +--------------------+ |
    | Spoke VNet 10.10.0.0/16 |                    |  | snet-hr  (VLAN10)  | |
    |  +--------------------+ |                    |  | 10.20.0.0/24       | |
    |  | snet-hr  (VLAN 10) | |                    |  +--------------------+ |
    |  | 10.10.0.0/24       | |                    |  | snet-fin (VLAN20)  | |
    |  |   [b1-hr-pc1]      | |                    |  | 10.20.1.0/24       | |
    |  +--------------------+ |                    |  +--------------------+ |
    |  | snet-fin (VLAN 20) | |                    |  | snet-it  (VLAN30)  | |
    |  | 10.10.1.0/24       | |                    |  | 10.20.2.0/24       | |
    |  |   [b1-fin-pc1]     | |                    |  |   [b2-hr-pc1]      | |
    |  +--------------------+ |                    |  +--------------------+ |
    |  | snet-it  (VLAN 30) | |                    |  [NAT Gateway]          |
    |  | 10.10.2.0/24       | |                    |  HR --X-- Finance       |
    |  |   [dns-server]     | |                    |  (null route blackhole) |
    |  |   [web-server]     | |                    +=========================+
    |  +--------------------+ |
    |  [NAT Gateway]          |
    |  HR --X-- Finance       |
    |  (null route blackhole) |
    +=========================+
```

### IP Addressing Scheme

| Network | Branch 1 (HQ) | Branch 2 |
|---|---|---|
| Hub VNet | 10.0.0.0/16 | 10.1.0.0/16 |
| GatewaySubnet | 10.0.1.0/27 | 10.1.1.0/27 |
| BastionSubnet | 10.0.2.0/27 | — |
| Spoke VNet | 10.10.0.0/16 | 10.20.0.0/16 |
| HR Subnet | 10.10.0.0/24 | 10.20.0.0/24 |
| Finance Subnet | 10.10.1.0/24 | 10.20.1.0/24 |
| IT Subnet | 10.10.2.0/24 | 10.20.2.0/24 |

### Static IP Assignments

| Host | IP Address | Subnet | Role |
|---|---|---|---|
| dns-server | 10.10.2.10 | Branch 1 IT | Windows DNS Server |
| web-server | 10.10.2.20 | Branch 1 IT | IIS Web Server (hosts this documentation) |
| b1-hr-pc1 | Dynamic (DHCP) | Branch 1 HR | HR Workstation |
| b1-fin-pc1 | Dynamic (DHCP) | Branch 1 Finance | Finance Workstation |
| b2-hr-pc1 | Dynamic (DHCP) | Branch 2 HR | Branch 2 HR Workstation |

---

## Phase-by-Phase Deployment Guide

### Initial Setup

1. Open `terraform.tfvars`
2. Set **all phase toggles to `false`**:
   ```hcl
   nat_gateway_enabled = false
   deploy_nsgs         = false
   deploy_route_tables = false
   deploy_dns          = false
   deploy_clients      = false
   deploy_vpn          = false
   deploy_web_server   = false
   deploy_chaos        = false
   ```
3. Set your admin password and VPN shared key
4. Run `terraform init` (first time only), then `terraform apply`

---

### Phase 1: Core Networking (always on)

**What deploys:** Hub and Spoke VNets, subnets (HR/Finance/IT), VNet peering, Azure Bastion (Branch 1 only)

**MIT 565 concepts:** VLANs, trunk links, IP addressing, CIDR subnetting, default gateway

**Azure resources created:**
- 2 Hub VNets (one per branch) with GatewaySubnet
- 2 Spoke VNets with 3 department subnets each
- 2 VNet peerings (Hub↔Spoke per branch)
- 1 Azure Bastion host (Branch 1, Standard SKU with tunneling)

**Deployment wait time:** ~5 minutes

---

### Phase 2: NAT Gateway

**Toggle:** `nat_gateway_enabled = true`

**What deploys:** NAT Gateway + public IP on both branches' spoke subnets

**MIT 565 concepts:** NAT (PAT/overload), inside/outside interfaces, private→public IP translation

**Azure resources created:**
- 2 NAT Gateways (one per branch)
- 2 Static public IPs
- 6 Subnet-to-NAT associations (3 department subnets per branch)

**Deployment wait time:** ~2 minutes

---

### Phase 3: NSGs (ACLs)

**Toggle:** `deploy_nsgs = true`

**What deploys:** Network Security Groups per department per branch (6 total)

**MIT 565 concepts:** Standard ACLs, extended ACLs, permit/deny, priority ordering, implicit deny-all

**NSG Rules Summary:**

| Department | Rule | Priority | Access | Cisco Equivalent |
|---|---|---|---|---|
| **IT** | Allow all VNet inbound | 100 | ✅ Allow | `permit ip any any` |
| **IT** | Allow all outbound | 100 | ✅ Allow | `permit ip any any` |
| **HR** | Allow ICMP from IT | 100 | ✅ Allow | `permit icmp 10.x.2.0 0.0.0.255 any` |
| **HR** | Allow RDP from IT | 110 | ✅ Allow | `permit tcp 10.x.2.0 0.0.0.255 any eq 3389` |
| **HR** | Allow from Finance | 120 | ✅ Allow | `permit ip 10.x.1.0 0.0.0.255 any` |
| **HR** | Deny RDP from Finance | 200 | ❌ Deny | `deny tcp 10.x.1.0 0.0.0.255 any eq 3389` |
| **Finance** | Allow ICMP from IT | 100 | ✅ Allow | `permit icmp 10.x.2.0 0.0.0.255 any` |
| **Finance** | Allow RDP from IT | 110 | ✅ Allow | `permit tcp 10.x.2.0 0.0.0.255 any eq 3389` |
| **Finance** | Deny RDP from HR | 200 | ❌ Deny | `deny tcp 10.x.0.0 0.0.0.255 any eq 3389` |

**Deployment wait time:** ~1 minute

---

### Phase 4: Route Tables (UDRs)

**Toggle:** `deploy_route_tables = true`

**What deploys:** Route tables with null routes (blackhole) between HR↔Finance on both branches, BGP propagation enabled

**MIT 565 concepts:** Static routing, routing tables, null routes (blackhole), administrative distance, defense in depth

**Routes Created:**

| Route Table | Destination | Next Hop | Effect | Cisco Equivalent |
|---|---|---|---|---|
| rt-hr | Finance subnet | `None` | **DROP** (blackhole) | `ip route 10.x.1.0 255.255.255.0 Null0` |
| rt-finance | HR subnet | `None` | **DROP** (blackhole) | `ip route 10.x.0.0 255.255.255.0 Null0` |
| rt-it | *(no blocking routes)* | — | Allow all | *(no null routes — admin access)* |

**All route tables:** `bgp_route_propagation_enabled = true` (allows VPN BGP learned routes)

**Deployment wait time:** ~1 minute

---

### Phase 5: DNS

**Toggle:** `deploy_dns = true`

**What deploys:** Azure Private DNS zone (`mit565.local`), A records, Windows DNS Server VM (10.10.2.10)

**MIT 565 concepts:** DNS zones, A records, name resolution, nslookup, DNS forwarding

**DNS Records:**

| Hostname | IP Address | Type |
|---|---|---|
| dns-server.mit565.local | 10.10.2.10 | A |
| web-server.mit565.local | 10.10.2.20 | A |
| branch1-client.mit565.local | 10.10.0.10 | A |
| branch2-client.mit565.local | 10.20.0.10 | A |

**VM deployed:** `dns-server` (Windows Server 2022 with DNS role installed, static IP 10.10.2.10)

**Desktop shortcuts on dns-server:** DNS Manager, IP Chicken

**Deployment wait time:** ~10 minutes (VM creation + DNS role installation)

---

### Phase 6: Client VMs

**Toggle:** `deploy_clients = true`

**What deploys:** 3 Windows workstation VMs (2 in Branch 1, 1 in Branch 2)

**MIT 565 concepts:** DHCP (dynamic IP), DNS client config, ARP, default gateway

**VMs deployed:**

| VM Name | Subnet | IP | DNS Server |
|---|---|---|---|
| b1-hr-pc1 | Branch 1 HR (10.10.0.0/24) | Dynamic | 10.10.2.10 |
| b1-fin-pc1 | Branch 1 Finance (10.10.1.0/24) | Dynamic | 10.10.2.10 |
| b2-hr-pc1 | Branch 2 HR (10.20.0.0/24) | Dynamic | 10.10.2.10 |

**Desktop shortcuts on all clients:** IP Chicken

**Deployment wait time:** ~10 minutes (3 VMs in parallel)

---

### Phase 7: VPN Gateway (WAN/BGP)

**Toggle:** `deploy_vpn = true`

**What deploys:** VPN Gateways on both branches, VNet-to-VNet connections with BGP

**MIT 565 concepts:** WAN links, site-to-site VPN, BGP dynamic routing, ASN, pre-shared keys

**Resources created:**
- 2 VPN Gateways (VpnGw1 SKU, route-based)
- 2 Public IPs for VPN endpoints
- 2 VNet-to-VNet connections (bidirectional, BGP-enabled)

**BGP Configuration:**

| Branch | ASN | Gateway |
|---|---|---|
| Branch 1 (HQ) | 65010 | vpngw-branch1-hq |
| Branch 2 | 65020 | vpngw-branch2 |

> **⚠️ Important:** VPN Gateways take **25-45 minutes** to deploy. Plan accordingly for class time. VPN Gateways also cost ~$0.04/hr each and run 24/7 — destroy promptly after class.

**Deployment wait time:** ~25-45 minutes

---

### Phase 8: Web Server (IIS)

**Toggle:** `deploy_web_server = true`

**What deploys:** IIS Web Server VM (10.10.2.20) with full lab documentation website

**MIT 565 concepts:** Application layer (HTTP), TCP 3-way handshake, client-server model, DNS→routing→TCP→HTTP chain

**VM deployed:** `web-server` (Windows Server 2022 with IIS role, static IP 10.10.2.20)

**Desktop shortcuts on web-server:** IIS Manager, IP Chicken

**Website features:**
- Complete lab documentation with network topology diagrams
- Concept mapping table (Cisco → Azure)
- IP addressing scheme
- NSG/ACL rules with Cisco equivalents
- Routing documentation (null routes, BGP, NAT Gateway)
- DNS configuration and lab exercises
- Interactive lab exercise guides
- TCP/IP stack walkthrough

**Deployment wait time:** ~10 minutes

---

### Phase 9: Chaos Studio

**Toggle:** `deploy_chaos = true`

**What deploys:** Azure Chaos Studio targets, capabilities, and experiments for fault injection testing

**MIT 565 concepts:** Network resilience, single points of failure, incident response, ACL misconfiguration impact

**Prerequisites:** Depends on resources from earlier phases — each experiment is conditionally created:
- DNS Outage experiment requires Phase 5 (DNS server)
- Web Outage experiment requires Phase 8 (Web server)
- Network Partition experiment requires Phase 3 (NSGs)

**Experiments deployed:**

| Experiment | Target | Fault | Duration | What Students Observe |
|---|---|---|---|---|
| `chaos-dns-outage` | DNS server VM | Graceful shutdown | 5 min | nslookup fails, ping by IP still works |
| `chaos-web-outage` | Web server VM | Graceful shutdown | 5 min | HTTP fails, DNS still resolves the name |
| `chaos-hr-network-partition` | HR NSG (Branch 1) | Deny-all inbound rule injected | 5 min | HR VM completely isolated |

**Role assignments created:**
- DNS experiment → Virtual Machine Contributor on dns-server
- Web experiment → Virtual Machine Contributor on web-server
- Network Partition experiment → Network Contributor on HR NSG

**Monitoring Dashboard & Alerts:**

An Azure Portal Dashboard (`MIT565-Chaos-Engineering-Dashboard`) is deployed with:

| Dashboard Tile | Metric | What to Watch |
|---|---|---|
| DNS Server CPU % | Real-time CPU utilization | Drops to 0% during `chaos-dns-outage` |
| DNS Server Network In/Out | Bytes per minute | Flatlines during outage |
| Web Server CPU % | Real-time CPU utilization | Drops to 0% during `chaos-web-outage` |
| Web Server Network In/Out | Bytes per minute | Flatlines during outage |
| Experiment Guide | Markdown | Step-by-step instructions |
| Monitoring Checklist | Markdown | What to verify during each experiment |
| Cisco Comparison | Markdown | Maps each experiment to Cisco equivalents |

**Metric Alerts** fire automatically when server CPU drops below 1%:
- `alert-dns-server-down` — fires during DNS outage experiment
- `alert-web-server-down` — fires during web server outage experiment
- View triggered alerts: Azure Portal → Monitor → Alerts

**Additional resources created:**
- Log Analytics Workspace (`log-mit565-chaos`) — enables metric collection
- Action Group (`ag-chaos-alerts`) — alert notification target

**How to open the dashboard:**
1. Azure Portal → search **Dashboards**
2. Click **Browse** → select `MIT565-Chaos-Engineering-Dashboard`
3. The dashboard shows real-time metrics — leave it open while running experiments

**How to run an experiment:**
1. Azure Portal → search **Chaos Studio** → **Experiments**
2. Select an experiment → click **Start** → Confirm
3. Monitor from a client VM — test connectivity during the fault
4. After 5 minutes, the fault auto-reverts (VM restarts, NSG rule removed)

**Deployment wait time:** ~2 minutes (no VMs created, just API resources)

> **Cost note:** Chaos Studio has no standing cost. Experiments cost $0.10 per experiment-minute when running. A 5-minute experiment costs $0.50.

---

## Concept Mapping: Cisco → Azure

| MIT 565 Concept | In-Class Tool | Azure Equivalent | Lab Component |
|---|---|---|---|
| VLANs | Switch VLAN config | Subnets | HR, Finance, IT subnets per branch |
| Trunk Links | 802.1Q trunking | VNet Peering | Hub↔Spoke peering |
| IP Addressing (CIDR) | Subnet masks, /24 | Address spaces | 10.x.x.x/16 and /24 prefixes |
| Default Gateway | Router interface IP | Azure virtual router | SDN default gateway per subnet |
| Static Routing | `ip route` command | User-Defined Routes (UDR) | Null routes (blackhole) HR↔Finance |
| Dynamic Routing (BGP) | `router ospf` / `router bgp` | VPN Gateway BGP | BGP ASN 65010/65020 across branches |
| Standard ACLs | `access-list` (source) | NSG (source filter) | NSG rules per department |
| Extended ACLs | `access-list` (src/dst/port) | NSG (src/dst/port/proto) | RDP allow/deny rules |
| DNS | `nslookup`, zone files | Private DNS + Windows DNS | mit565.local zone, A records |
| ARP | `arp -a`, `show arp` | VM NIC ARP tables | Run `arp -a` on any VM |
| NAT (PAT/Overload) | `ip nat inside source list` | NAT Gateway (SNAT) | NAT Gateway on both branches |
| WAN Links | Serial/MPLS connections | VPN Gateway connections | Branch1↔Branch2 VPN tunnel |
| Null Route | `ip route x.x.x.0 Null0` | UDR `next_hop_type = "None"` | HR↔Finance blackhole on both branches |
| Chaos/Failure Testing | Pulling cables, `shutdown` interface | Azure Chaos Studio | DNS outage, web outage, NSG deny-all experiments |

---

## Lab Exercises

### Lab 1: IP Addressing & Subnetting

**Objective:** Verify IP configuration and understand CIDR notation.

**From any VM (via Bastion):**
```cmd
C:\> ipconfig /all
```

**What to observe:**
- IPv4 Address (e.g., 10.10.0.4 for HR workstation)
- Subnet Mask: 255.255.255.0 (/24 = 254 usable hosts)
- Default Gateway: 10.10.0.1 (Azure virtual router)
- DNS Server: 10.10.2.10 (lab DNS server)

---

### Lab 2: ARP & MAC Addresses

**Objective:** Observe ARP resolution and virtual MAC addresses.

**From b1-hr-pc1:**
```cmd
C:\> arp -d *                 (clear ARP cache)
C:\> arp -a                   (observe: table is empty or minimal)
C:\> ping 10.10.2.10          (DNS server in IT subnet — should succeed)
C:\> arp -a                   (observe: gateway MAC now appears)
C:\> ping 10.10.1.x           (Finance workstation IP — null-routed!)
C:\> arp -a                   (observe: still only gateway MAC, no Finance entry)
```

**What to observe:**
- Before ping: ARP table is empty or only has link-local entries
- After ping to IT (10.10.2.10): The default gateway (10.10.0.1) MAC entry appears — this is because Finance and IT are on **different subnets**, so the packet is forwarded through the gateway. ARP only resolves **local segment** (Layer 2) neighbors
- After ping to Finance (10.10.1.x): Request times out (null route drops traffic), but the gateway ARP entry is **still present** — the VM sent the packet to the gateway, which then dropped it at the Azure SDN layer
- You will **never** see 10.10.1.x or 10.10.2.10 in the ARP table because they are on different subnets — only the next-hop (gateway) MAC is resolved

---

### Lab 3: DNS Resolution

**Objective:** Test name resolution using nslookup and Resolve-DnsName.

**From any VM:**
```cmd
C:\> nslookup web-server.mit565.local
C:\> nslookup dns-server.mit565.local
C:\> nslookup branch2-client.mit565.local

REM PowerShell equivalent:
C:\> Resolve-DnsName -Name web-server.mit565.local -Type A
```

**What to observe:**
- Server field shows 10.10.2.10 (your lab DNS server)
- Names resolve to the static IPs configured in the DNS zone
- Names resolve from both Branch 1 AND Branch 2 VMs (DNS zone is linked to all VNets)

**On the DNS server itself (dns-server, 10.10.2.10):**
- Open **DNS Manager** (desktop shortcut) → Expand Forward Lookup Zones → `mit565.local`
- View the A records — compare to what nslookup returns

---

### Lab 4: Routing Tables & Null Routes (UDRs)

**Objective:** Examine the Windows routing table and observe null route behavior.

**From b1-hr-pc1 (HR workstation):**
```cmd
C:\> route print
```

**What to observe in `route print`:**
- Network destination 0.0.0.0 → Gateway 10.10.0.1 (default route)
- Local subnet 10.10.0.0/24 → On-link (directly connected)
- The Azure UDRs (null routes) are applied at the platform level — they won't appear in the Windows routing table, but they DO affect traffic

**Test the null route:**
```cmd
REM From HR workstation — try to reach Finance:
C:\> ping 10.10.1.x
REM Result: Request timed out (packets are blackholed by the null route!)

REM From HR workstation — try to reach IT (no null route):
C:\> ping 10.10.2.10
REM Result: Reply from 10.10.2.10 (IT subnet is reachable)
```

**Test cross-branch routing (requires Phase 7 VPN):**
```cmd
C:\> tracert 10.20.0.x
REM Trace path from Branch 1 → Branch 2 via VPN gateway (BGP route)
```

---

### Lab 5: NSG / ACL Testing

**Objective:** Test NSG rules that permit and deny traffic between departments.

**From b1-hr-pc1 (HR workstation):**
```cmd
REM Ping Finance (ICMP) — allowed by null route? No! Blocked at Layer 3
C:\> ping 10.10.1.x                    → BLOCKED (null route)

REM Ping IT (ICMP) — allowed?
C:\> ping 10.10.2.10                   → ALLOWED (no deny rule, IT allows all VNet)

REM RDP to Finance:
C:\> mstsc /v:10.10.1.x                → BLOCKED (null route + NSG deny)

REM RDP to IT:
C:\> mstsc /v:10.10.2.10               → ALLOWED (IT NSG allows all VNet inbound — admin access)
```

**From IT workstation (if you RDP to it from another IT machine or use Bastion):**
```cmd
REM IT can ping everyone (admin VLAN):
C:\> ping 10.10.0.x                    → ALLOWED
C:\> ping 10.10.1.x                    → ALLOWED
C:\> mstsc /v:10.10.0.x                → ALLOWED (can RDP to HR)
C:\> mstsc /v:10.10.1.x                → ALLOWED (can RDP to Finance)
```

---

### Lab 6: Defense in Depth (Routing + ACLs)

**Objective:** Demonstrate that two independent security layers protect department isolation.

> **Note:** This exercise involves temporarily modifying Azure resources in the portal. Only the instructor should perform the modifications; students observe.

**Scenario A: What happens if we remove ONLY the null route?**
1. In Azure Portal → Route Tables → `rt-hr-branch1-hq` → Routes → Delete `blackhole-to-finance`
2. From b1-hr-pc1: `ping 10.10.1.x` — **now works!** (Routing layer removed; NSG only blocks RDP, not ICMP)
3. From b1-hr-pc1: `mstsc /v:10.10.1.x` — **still blocked!** (Finance NSG `Deny-RDP-From-HR` at priority 200 catches it)
4. Re-run `terraform apply` to restore the null route

> **Key insight:** The null route was blocking *everything* (like `ip route Null0`). The NSG is more surgical — it only blocks specific protocols like RDP. Removing one layer gives partial access, not full access. This is exactly like Cisco: a null route drops all traffic, while an ACL can selectively permit or deny.

**Scenario B: What happens if we remove ONLY the NSG deny rule?**
1. In Azure Portal → NSGs → `nsg-finance-branch1-hq` → Inbound rules → Delete `Deny-RDP-From-HR`
2. From b1-hr-pc1: `ping 10.10.1.x` — **still blocked!** (Null route drops all traffic before NSG is even checked)
3. From b1-hr-pc1: `mstsc /v:10.10.1.x` — **still blocked!** (Null route drops all traffic)
4. Re-run `terraform apply` to restore the NSG rule

**Key takeaway:** The null route operates at **Layer 3** (routing) and blocks everything. The NSG operates at **Layer 4** (ACL) and blocks selectively. Together they provide **defense in depth** — removing one layer still leaves protection, but each layer protects differently. This mirrors real-world network security where you combine routing controls with access control lists.

---

### Lab 7: NAT & Outbound Internet

**Objective:** Verify NAT Gateway behavior and understand SNAT.

**From any VM:**
1. Open the **IP Chicken** shortcut on the desktop (opens https://www.ipchicken.com in Edge)
2. Note the public IP address shown

**From another VM in the SAME branch:**
1. Open IP Chicken — note the public IP

**What to observe:**
- All VMs in Branch 1 show the **same public IP** (NAT Gateway's IP)
- All VMs in Branch 2 show a **different public IP** (Branch 2's own NAT Gateway)
- This is PAT/overload — many private IPs share one public IP

**Compare with Terraform output:**
```bash
terraform output nat_gateway_public_ip
```

---

### Lab 8: Cross-Branch VPN Connectivity

**Objective:** Prove branch-to-branch connectivity over VPN and observe BGP routing.

> **Requires:** Phase 7 (VPN Gateway) deployed

**From b1-hr-pc1 (Branch 1):**
```cmd
REM Ping Branch 2 HR workstation:
C:\> ping 10.20.0.x                    → ALLOWED (across VPN)

REM Trace the route:
C:\> tracert 10.20.0.x
REM Shows path through VPN gateway

REM RDP to Branch 2 (proves VPN tunnel works):
C:\> mstsc /v:10.20.0.x
```

---

### Lab 9: Web Server (HTTP over TCP)

**Objective:** Access the documentation website and understand the HTTP flow.

**From any VM:**
```cmd
C:\> curl http://10.10.2.20
C:\> curl http://web-server.mit565.local

REM Or open Edge and browse to:
http://web-server.mit565.local
```

**On the web-server VM:**
- Open **IIS Manager** (desktop shortcut) → Expand Sites → Default Web Site
- View the physical path: `C:\inetpub\wwwroot\index.html`
- View bindings: Port 80, HTTP

---

### Lab 10: End-to-End TCP/IP Stack Walkthrough

**Objective:** Trace every layer of the TCP/IP stack when loading the web page.

When a student opens `http://web-server.mit565.local` from b1-hr-pc1:

| Layer | TCP/IP Model | What Happens | Azure Component |
|---|---|---|---|
| 5 | Application | Browser sends HTTP GET for index.html | IIS Web Server |
| 4 | Transport | TCP 3-way handshake (SYN, SYN-ACK, ACK) on port 80 | Azure SDN TCP stack |
| 3 | Internet | IP packet routed: client IP → 10.10.2.20 | UDR / Azure virtual router |
| 2 | Network Access | Ethernet frame with destination MAC (ARP resolved) | Azure virtual switch / NIC |
| 1 | Physical | Bits transmitted over Azure backbone fiber | Azure datacenter fabric |

**Exercise:** Have students draw this diagram on the whiteboard for cross-branch access (b2-hr-pc1 → web-server.mit565.local). What additional steps are involved? (VPN encapsulation, BGP route lookup, NAT for ARP across branches)

---

### Lab 11: Chaos Engineering (Failure Testing)

**Objective:** Use Azure Chaos Studio to inject controlled failures, observe the impact on network services, and monitor metrics in real-time using the Azure Portal Dashboard.

> **Requires:** Phase 9 (Chaos Studio) deployed, plus the experiments' prerequisite phases

**Setup: Open the Monitoring Dashboard**

Before running any experiment, open the dashboard so you can watch metrics change in real-time:
1. Azure Portal → search **Dashboards** → **Browse**
2. Select `MIT565-Chaos-Engineering-Dashboard`
3. Keep this open in a separate browser tab during all experiments

**Experiment A: DNS Server Outage**

1. From b1-hr-pc1, verify DNS works:
```cmd
C:\> nslookup web-server.mit565.local
REM Result: 10.10.2.20 (DNS working)

C:\> ping 10.10.2.10
REM Result: Reply from 10.10.2.10 (DNS server reachable)
```

2. In Azure Portal → Chaos Studio → Experiments → select `chaos-dns-outage` → **Start**

3. Wait ~30 seconds for the DNS server to shut down, then test:
```cmd
C:\> nslookup web-server.mit565.local
REM Result: TIMEOUT (DNS server is down!)

C:\> ping 10.10.2.10
REM Result: Request timed out (server VM is shut down)

C:\> ping 10.10.2.20
REM Result: Reply from 10.10.2.20 (web server still reachable by IP!)

C:\> curl http://10.10.2.20
REM Result: HTML response (website works by IP, just not by name)
```

4. After 5 minutes, the DNS server auto-restarts. Verify recovery:
```cmd
C:\> nslookup web-server.mit565.local
REM Result: 10.10.2.20 (DNS restored!)
```

5. **Check the dashboard:** DNS Server CPU % chart should show the dip to 0% and recovery. Check Azure Portal → Monitor → Alerts to see the `alert-dns-server-down` metric alert that fired.

**Experiment B: Network Partition (HR Isolation)**

1. In Azure Portal → Chaos Studio → Experiments → select `chaos-hr-network-partition` → **Start**

2. From b1-hr-pc1 (HR VM) — test all connectivity:
```cmd
C:\> ping 10.10.2.10
REM Result: Request timed out (HR is completely isolated!)

C:\> ping 10.10.1.x
REM Result: Request timed out (can't reach Finance either)

C:\> nslookup web-server.mit565.local
REM Result: TIMEOUT (can't reach DNS server)
```

3. From an IT VM or via Bastion to b1-fin-pc1 — verify OTHER subnets still work:
```cmd
C:\> ping 10.10.2.10
REM Result: Reply (Finance/IT unaffected — only HR is partitioned!)
```

4. After 5 minutes, the deny-all NSG rule is automatically removed. HR connectivity restores.

**Experiment C: Web Server Outage**

1. From b1-hr-pc1, verify the web server is reachable:
```cmd
C:\> nslookup web-server.mit565.local
REM Result: 10.10.2.20 (DNS resolves the name)

C:\> curl http://web-server.mit565.local
REM Result: HTML response (website is serving content)

C:\> ping 10.10.2.20
REM Result: Reply from 10.10.2.20 (server reachable)
```

2. In Azure Portal → Chaos Studio → Experiments → select `chaos-web-outage` → **Start**

3. Wait ~30 seconds for the web server to shut down, then test:
```cmd
C:\> nslookup web-server.mit565.local
REM Result: 10.10.2.20 (DNS still resolves — it doesn't know the server is down!)

C:\> curl http://web-server.mit565.local
REM Result: Connection refused / timeout (web server is down!)

C:\> ping 10.10.2.20
REM Result: Request timed out (server VM is shut down)

C:\> ping 10.10.2.10
REM Result: Reply from 10.10.2.10 (DNS server is fine — this is an app-layer failure)
```

4. After 5 minutes, the web server auto-restarts. Verify recovery:
```cmd
C:\> curl http://web-server.mit565.local
REM Result: HTML response (website is back!)
```

5. **Check the dashboard:** Web Server CPU % chart should show the dip to 0% and recovery. Check Azure Portal → Monitor → Alerts to see the `alert-web-server-down` metric alert that fired.

> **Key lesson:** DNS resolved the name successfully even though the server was down. This demonstrates the difference between **network-layer** and **application-layer** failures. The path to the server worked, but the service wasn't running — exactly like a Cisco switch where the interface is up but the connected server has crashed.

---

## Connecting to VMs

### Azure Bastion (Branch 1 Only)

**Browser-based RDP (simplest):**
1. Go to Azure Portal → Virtual Machines → select a Branch 1 VM
2. Click **Connect** → **Bastion**
3. Enter username: `adminuser`, password: (from terraform.tfvars)

**Native RDP client (better experience, supports copy/paste and BGInfo wallpaper):**
```bash
# Install the Bastion SSH/RDP extension (first time only):
az extension add --name bastion

# Create a tunnel to a specific VM:
az network bastion tunnel \
  --name bastion-branch1-hq \
  --resource-group rg-mit565-branch1-hq \
  --target-resource-id $(az vm show -g rg-mit565-branch1-hq -n VM_NAME --query id -o tsv) \
  --resource-port 3389 \
  --port 3389

# Then connect with Remote Desktop to localhost:3389
```

Replace `VM_NAME` with: `b1-hr-pc1`, `b1-fin-pc1`, `dns-server`, or `web-server`

### Accessing Branch 2 VMs (No Bastion)

Branch 2 has no Bastion host — simulating a remote branch office with no local management infrastructure.

1. Bastion into any Branch 1 VM (e.g., `b1-hr-pc1`)
2. From that VM, open Remote Desktop: `mstsc /v:10.20.0.x`
3. Login with the same credentials

> This workflow itself is a lab exercise — it proves the VPN tunnel and BGP routing work!

---

## Cost Controls

### Spot VMs

Save 60-90% on VM costs by enabling Spot pricing:

```hcl
# In terraform.tfvars:
use_spot = true
```

Spot VMs can be evicted by Azure when capacity is needed. For lab/dev workloads this is rarely an issue, but don't use Spot for production or during critical exams.

### Tagging

All resources are tagged for cost tracking:

```hcl
tags = {
  project     = "MIT-565-Azure-Lab"
  course      = "MIT 565 - Internetworking"
  university  = "Elmhurst University"
  environment = "lab"
  deployed_by = "terraform"
}
```

Use these tags in Azure Cost Management to filter and track lab spending.

### Partial Deployment

Only deploy what you need for today's lesson. VPN Gateways (~$0.04/hr each) and Bastion (~$0.26/hr) are the most expensive — skip Phase 7 unless you're teaching WAN/BGP.

---

## Tearing Down the Lab

```bash
# Destroy everything (will prompt for confirmation):
terraform destroy

# Destroy without confirmation prompt:
terraform destroy -auto-approve
```

> **⚠️ VPN Gateways take 15-20 minutes to delete.** Be patient — don't interrupt the destroy or you may have orphaned resources that require manual cleanup in the Azure portal.

### Partial Teardown

To remove only specific phases, change their toggle to `false` in `terraform.tfvars` and run `terraform apply`. For example, to remove VPN Gateways but keep everything else:

```hcl
deploy_vpn = false
```

```bash
terraform apply
```

---

## Troubleshooting

| Problem | Cause | Fix |
|---|---|---|
| `Standard_B2s` unavailable | SKU capacity exhaustion in region | Change `vm_size = "Standard_B2ms"` in terraform.tfvars |
| VNet peering fails with gateway error | VPN Gateway not created yet | Terraform handles this with `depends_on` — just re-run `terraform apply` |
| Can't ping across branches | BGP propagation disabled on route tables, or VPN Gateways still provisioning | Wait for VPN GW deployment; verify `bgp_route_propagation_enabled = true` |
| BGInfo not showing on Bastion | Bastion browser RDP disables wallpaper rendering | Use native client: `az network bastion tunnel ...` |
| `terraform destroy` hangs | VPN Gateway deletion is slow (~15-20 min) | Wait patiently; don't Ctrl+C |
| HR can ping Finance | Route tables not deployed (Phase 4 = false) | Enable `deploy_route_tables = true` and apply |
| DNS resolution fails | DNS server not deployed, or VM DNS not pointed to 10.10.2.10 | Enable Phase 5; check VM NIC DNS settings in portal |
| Bastion tunnel fails | Azure CLI not logged in, or Bastion extension missing | Run `az login` and `az extension add --name bastion` |
| Chaos Studio "tenant not found" 404 error | `Microsoft.Chaos` resource provider not registered | Run `az provider register --namespace Microsoft.Chaos` and wait ~1-2 min, then re-apply |
| Chaos experiment won't start | Managed Identity missing role assignment | Verify role assignments in Azure Portal → Chaos Studio experiment → Identity |
| Chaos experiment target not found | Prerequisite phase not deployed | Enable the required phase (e.g., Phase 5 for DNS outage) and `terraform apply` |
| Dashboard shows no metrics | VMs not running yet, or dashboard created before VMs | Wait for VMs to start and generate metrics (5-10 min), then refresh dashboard |
| Alerts not firing during chaos | Window size is 5 min — alert needs sustained low CPU | Wait for the full experiment duration; check Alert rules → Monitor → Alerts |

---

## Variables Reference

| Variable | Type | Default | Description |
|---|---|---|---|
| `region_1` | string | `centralus` | Branch 1 (HQ) Azure region |
| `region_2` | string | `eastus2` | Branch 2 Azure region |
| `admin_username` | string | `adminuser` | VM admin username |
| `admin_password` | string | *(required)* | VM admin password (sensitive) |
| `vpn_shared_key` | string | *(required)* | VPN tunnel pre-shared key (sensitive) |
| `vm_size` | string | `Standard_B2s` | VM SKU (use `Standard_B2ms` if B2s unavailable) |
| `nat_gateway_enabled` | bool | `true` | Phase 2: NAT Gateway |
| `deploy_nsgs` | bool | `true` | Phase 3: Network Security Groups |
| `deploy_route_tables` | bool | `true` | Phase 4: Route Tables with null routes |
| `deploy_dns` | bool | `true` | Phase 5: DNS zone + DNS server VM |
| `deploy_clients` | bool | `true` | Phase 6: Client workstation VMs |
| `deploy_vpn` | bool | `true` | Phase 7: VPN Gateways + BGP |
| `deploy_web_server` | bool | `true` | Phase 8: IIS web server + documentation site |
| `deploy_chaos` | bool | `true` | Phase 9: Azure Chaos Studio experiments |
| `use_spot` | bool | `false` | Use Spot VM pricing (60-90% savings) |
| `tags` | map(string) | `{}` | Tags applied to all resources |

---

> **MIT 565 — Internetworking | Elmhurst University MCIT Program**
> Deployed with Terraform on Microsoft Azure
