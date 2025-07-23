#---------------------------
# Variables
#---------------------------

# Azure Environment
variable "location" {
  default = "<region>"
}

variable "project_name" {
  default = "logexport"
}

variable "resource_group_name" {
  default = "<rg_name>"
  type    = string
}

variable "log_analytics_workspace_id" {
  default = "/subscriptions/<subscription_id>/resourceGroups/<rg_name>/providers/Microsoft.OperationalInsights/workspaces/<la_workspace_name>"
  type    = string
}

# Identities
variable "managed_identity_id" {
  default = "/subscriptions/<subscription_id>/resourceGroups/<rg_name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<user_managed_identity_name>"
}

variable "workspace_user_id" {
  default = "<user_principal_id_to_assign_workspace_to>"
  type    = string
}

# External IPs
variable "external_ips" {
  description = "The external IPs allowed to access the workspace."
  type        = list(any)
  default     = ["<ip_1>", "<ip_2>"]
}

# Subnets
variable "vnet_address_space" {
  type        = list(string)
  description = "IPv4 space of the virtual network"
  default     = ["10.0.0.0/16"]
}

variable "mlw_subnet_space" {
  type        = list(string)
  description = "IPv4 space of the ML workspace subnet"
  default     = ["10.0.1.0/24"]
}