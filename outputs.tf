###############################################################################
# MIT 565 – Internetworking Azure Lab
# Outputs – Useful info for lab exercises
# Outputs use try() so they work regardless of which phases are enabled
###############################################################################

# ── Phase 1: Network Info ────────────────────────────────────────────────────
output "branch1_hub_vnet_id" {
  value = module.network_branch1.hub_vnet_id
}

output "branch1_spoke_vnet_id" {
  value = module.network_branch1.spoke_vnet_id
}

output "branch2_hub_vnet_id" {
  value = module.network_branch2.hub_vnet_id
}

output "branch2_spoke_vnet_id" {
  value = module.network_branch2.spoke_vnet_id
}

# ── Phase 2: NAT Gateway ────────────────────────────────────────────────────
output "nat_gateway_public_ip" {
  description = "NAT Gateway public IP for outbound SNAT (Branch 1)"
  value       = module.network_branch1.nat_gateway_public_ip
}

# ── Phase 5: DNS ─────────────────────────────────────────────────────────────
output "dns_server_private_ip" {
  description = "Private IP of the DNS server (use for nslookup exercises)"
  value       = try(module.dns_server[0].private_ip_address, null)
}

output "dns_zone_name" {
  description = "Private DNS zone name for nslookup exercises"
  value       = try(module.dns[0].dns_zone_name, null)
}

# ── Phase 6: Client VMs ─────────────────────────────────────────────────────
output "branch1_hr_client_ip" {
  description = "Branch 1 HR workstation private IP"
  value       = try(module.client_branch1_hr[0].private_ip_address, null)
}

output "branch1_finance_client_ip" {
  description = "Branch 1 Finance workstation private IP"
  value       = try(module.client_branch1_fin[0].private_ip_address, null)
}

output "branch2_hr_client_ip" {
  description = "Branch 2 HR workstation private IP"
  value       = try(module.client_branch2_hr[0].private_ip_address, null)
}

# ── Phase 8: Web Server ─────────────────────────────────────────────────────
output "web_server_private_ip" {
  description = "Private IP of the IIS web server (http://10.10.2.20 or http://web-server.mit565.local)"
  value       = try(module.web_server[0].private_ip_address, null)
}

# ── Lab Exercise Quick Reference ─────────────────────────────────────────────
output "lab_exercises" {
  description = "Quick reference for MIT 565 lab exercises to run on the VMs"
  value       = <<-EOT

    ╔══════════════════════════════════════════════════════════════════════╗
    ║  MIT 565 Azure Lab – Exercise Quick Reference                        ║
    ╠══════════════════════════════════════════════════════════════════════╣
    ║                                                                      ║
    ║  1. IP ADDRESSING & SUBNETTING                                       ║
    ║     ipconfig /all              (view IP, subnet mask, gateway)       ║
    ║     Compare CIDR /24 = 255.255.255.0 = 254 usable hosts              ║
    ║                                                                      ║
    ║  2. ARP & MAC ADDRESSES                                              ║
    ║     arp -a                     (view ARP cache)                      ║
    ║     ping 10.10.1.x then arp -a (watch ARP table populate)            ║
    ║                                                                      ║
    ║  3. DNS RESOLUTION                                                   ║
    ║     nslookup dns-server.mit565.local                                 ║
    ║     nslookup branch1-client.mit565.local                             ║
    ║     Resolve-DnsName dns-server.mit565.local                          ║
    ║                                                                      ║
    ║  4. ROUTING                                                          ║
    ║     route print                (view routing table)                  ║
    ║     tracert 10.20.0.x          (trace route to Branch 2)             ║
    ║     pathping 10.10.1.x         (trace to Finance subnet)             ║
    ║                                                                      ║
    ║  5. ACL / NSG TESTING                                                ║
    ║     From HR: ping Finance subnet (should work)                       ║
    ║     From HR: RDP to Finance (should be blocked by NSG)               ║
    ║     From IT:  RDP to any subnet (should work – admin access)         ║
    ║                                                                      ║
    ║  6. CROSS-BRANCH CONNECTIVITY (VPN)                                  ║
    ║     From Branch 1: ping 10.20.0.x (Branch 2 HR)                      ║
    ║     From Branch 1: tracert 10.20.0.x (see VPN hop)                   ║
    ║                                                                      ║
    ║  7. WEB SERVER (HTTP over TCP/IP)                                    ║
    ║     curl http://10.10.2.20              (by IP)                      ║
    ║     curl http://web-server.mit565.local  (by DNS name)               ║
    ║     Open browser → http://web-server.mit565.local                    ║
    ║     Full stack: DNS → ARP → Route → TCP → HTTP                       ║
    ║                                                                      ║
    ╚══════════════════════════════════════════════════════════════════════╝

  EOT
}