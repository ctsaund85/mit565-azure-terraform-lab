###############################################################################
# Windows Server Module – Variables
# Deploys a Windows Server VM that can serve as DNS/AD server
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
  default     = "winsvr"
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

variable "private_ip_address" {
  description = "Static private IP for the server (important for DNS)"
  type        = string
  default     = null
}

variable "install_dns" {
  description = "Install Windows DNS Server role via PowerShell"
  type        = bool
  default     = false
}

variable "dns_servers" {
  description = "Custom DNS server IPs to configure on the NIC"
  type        = list(string)
  default     = []
}

variable "install_iis" {
  description = "Install IIS Web Server role and deploy a website"
  type        = bool
  default     = false
}

variable "iis_content_url" {
  description = "URL to an HTML file to download and deploy to IIS wwwroot"
  type        = string
  default     = null
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