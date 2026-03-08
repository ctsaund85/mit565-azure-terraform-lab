###############################################################################
# NSG Module – Variables
# Network Security Groups = Azure equivalent of ACLs
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
  type = string
}

variable "finance_subnet_prefix" {
  type = string
}

variable "it_subnet_prefix" {
  type = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
