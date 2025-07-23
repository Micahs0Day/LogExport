#---------------------------
# Variables
#---------------------------

# Azure Environment
variable "location" {
  default = "eastus"
}

variable "tenant_id" {
  default = "<tenant_id>"
}

variable "subscription_id" {
  default = "<sub_id>"
}

variable "project" {
  default = "logexport"
}

variable "resource_group_name" {
  default = "<rg-name>"
  type    = string
}

variable "log_analytics_workspace_id" {
  default = "/subscriptions/<sub_id>/resourceGroups/<rg_name>/providers/Microsoft.OperationalInsights/workspaces/<la_workspace_id>"
  type    = string
}

# Identities
variable "user_obj-id" {
  default = "<personal_user_obj_id>"
  type    = string
}

variable "sp_object_id" {
  default = "<service_principal_obj_id>"
}

variable "managed_identity" {
  default = "/subscriptions/<sub_id>/resourceGroups/<rg_name>/providers/Microsoft.ManagedIdentity/userAssignedIdentities/<mlws-identity-name>"
}

variable "managed_identity_id" {
  default = "<managed_principal_id>"
}

# External IPs
variable "external_ips" {
  description = "The external IPs allowed to access the workspace."
  type        = list(any)
  default     = ["<other>", "<my_public_ip>"]
}

variable "my_public_ip" {
  default = ["<IP>/32"]
  type    = list(any)
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
