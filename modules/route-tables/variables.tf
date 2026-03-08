###############################################################################
# Route Tables Module – Variables
# User-Defined Routes = Azure equivalent of static routing / routing tables
# Null routes (blackhole) = Azure equivalent of "ip route x.x.x.x Null0"
###############################################################################

variable "resource_group_name" {
  type = string
}

variable "region" {
  type = string
}

variable "branch_name" {
  type = string
}

variable "hr_subnet_id" {
  type = string
}

variable "finance_subnet_id" {
  type = string
}

variable "it_subnet_id" {
  type = string
}

variable "hr_subnet_prefix" {
  description = "HR subnet CIDR (used for null route from Finance)"
  type        = string
}

variable "finance_subnet_prefix" {
  description = "Finance subnet CIDR (used for null route from HR)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
