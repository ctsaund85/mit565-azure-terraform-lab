###############################################################################
# Hub-Spoke VNet Module – Variables
# MIT 565 Azure Lab: Demonstrates VNet segmentation, subnetting (CIDR),
# VLANs-as-subnets, peering, VPN gateway, Bastion, and NAT Gateway.
###############################################################################

variable "resource_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "branch_name" {
  description = "Friendly name for this branch (e.g. branch1-centralus)"
  type        = string
}

# ── Hub VNet ─────────────────────────────────────────────────────────────────
variable "hub_address_space" {
  type = list(string)
}

variable "gateway_subnet_prefix" {
  description = "/27 subnet reserved for VPN Gateway"
  type        = string
}

variable "bastion_subnet_prefix" {
  description = "/27 subnet reserved for Azure Bastion"
  type        = string
}

variable "bastion_enabled" {
  type    = bool
  default = false
}

variable "nat_gateway_enabled" {
  description = "Deploy NAT Gateway for outbound internet (SNAT) on spoke subnets"
  type        = bool
  default     = false
}

variable "vpn_gateway_enabled" {
  type    = bool
  default = false
}

variable "vpn_gateway_depends_on_id" {
  description = "Optional VPN gateway ID to depend on (serializes gateway creation to prevent Azure failures)"
  type        = string
  default     = null
}

variable "bgp_asn" {
  description = "BGP ASN for the VPN Gateway (must be unique per gateway for BGP peering)"
  type        = number
  default     = 65010
}

# ── Spoke VNet ───────────────────────────────────────────────────────────────
variable "spoke_address_space" {
  type = list(string)
}

variable "hr_subnet_prefix" {
  description = "Subnet for the HR department (simulates HR VLAN)"
  type        = string
}

variable "finance_subnet_prefix" {
  description = "Subnet for the Finance department (simulates Finance VLAN)"
  type        = string
}

variable "it_subnet_prefix" {
  description = "Subnet for the IT department (simulates IT VLAN)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}