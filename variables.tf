###############################################################################
# MIT 565 – Internetworking Azure Lab
# Root Variables
###############################################################################

variable "region_1" {
  description = "Branch 1 (HQ) region"
  type        = string
  default     = "centralus"
}

variable "region_2" {
  description = "Branch 2 region"
  type        = string
  default     = "eastus2"
}

variable "admin_username" {
  description = "Admin username for all VMs"
  type        = string
  default     = "adminuser"
}

variable "admin_password" {
  description = "Admin password for all VMs"
  type        = string
  sensitive   = true
}

variable "vm_size" {
  description = "VM size for all virtual machines"
  type        = string
  default     = "Standard_B2s"
}

variable "vpn_shared_key" {
  description = "Pre-shared key for the VPN gateway connection between branches"
  type        = string
  sensitive   = true
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  DEMO PHASE TOGGLES                                                    ║
# ║  Set to true/false in terraform.tfvars for incremental deployment      ║
# ║  Phase 1 (networking) is always deployed                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "nat_gateway_enabled" {
  description = "Phase 2: Deploy NAT Gateway for outbound internet access (SNAT)"
  type        = bool
  default     = true
}

variable "deploy_nsgs" {
  description = "Phase 3: Deploy Network Security Groups (ACLs)"
  type        = bool
  default     = true
}

variable "deploy_route_tables" {
  description = "Phase 4: Deploy route tables (User-Defined Routes)"
  type        = bool
  default     = true
}

variable "deploy_dns" {
  description = "Phase 5: Deploy DNS (Azure Private DNS zone + Windows DNS server)"
  type        = bool
  default     = true
}

variable "deploy_clients" {
  description = "Phase 6: Deploy client VMs (department workstations)"
  type        = bool
  default     = true
}

variable "deploy_vpn" {
  description = "Phase 7: Deploy VPN Gateways and cross-branch connections (~$0.04/hr per gateway)"
  type        = bool
  default     = true
}

variable "deploy_web_server" {
  description = "Phase 8: Deploy IIS web server with documentation website"
  type        = bool
  default     = true
}

variable "deploy_chaos" {
  description = "Phase 9: Deploy Azure Chaos Studio experiments for resilience testing"
  type        = bool
  default     = true
}

# ╔═══════════════════════════════════════════════════════════════════════════╗
# ║  COST & TAGGING CONTROLS                                               ║
# ╚═══════════════════════════════════════════════════════════════════════════╝

variable "use_spot" {
  description = "Use Azure Spot VMs for all virtual machines (saves ~60-90%% but VMs can be evicted)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags applied to all resources for cost tracking and organization"
  type        = map(string)
  default     = {}
}