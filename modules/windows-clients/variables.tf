###############################################################################
# Windows Client Module – Variables
# Deploys a Windows workstation VM in a department subnet
###############################################################################

variable "resource_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "subnet_id" {
  type = string
}

variable "vm_name" {
  description = "Name for the VM (max 15 chars for Windows)"
  type        = string
  default     = "winclient"
}

variable "vm_size" {
  type    = string
  default = "Standard_B2s"
}

variable "admin_username" {
  type    = string
  default = "adminuser"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "dns_servers" {
  description = "Custom DNS server IPs to configure on the NIC"
  type        = list(string)
  default     = []
}

variable "use_spot" {
  description = "Use Azure Spot pricing for this VM (can be evicted)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}