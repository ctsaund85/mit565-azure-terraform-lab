###############################################################################
# DNS Module – Variables
# Azure Private DNS Zones for internal name resolution
###############################################################################

variable "resource_group_name" {
  type = string
}

variable "dns_zone_name" {
  description = "Private DNS zone name (e.g. mit565.local)"
  type        = string
  default     = "mit565.local"
}

variable "vnet_links" {
  description = "Map of VNet IDs to link to this DNS zone for auto-resolution"
  type        = map(string)
}

variable "dns_records" {
  description = "Map of A records to create (hostname => IP)"
  type        = map(string)
  default     = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
