#---------------------------
# Variables
#---------------------------

# Provider Config
variable "location" {
  default = "eastus2"
}

variable "tenant_id" {
  default = ""
}

variable "subscription_id" {
  default = ""
}

variable "project" {
  default = "log-export"
}

variable "resource_group_name" {
  default = ""
  type    = string
}

# External IPs
variable "external_ips" {
  description = "The external IPs allowed to access the workspace."
  type        = list(any)
  default     = [""]
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

variable "bastion_subnet_space" {
  type        = list(string)
  description = "Address space of the bastion subnet"
  default     = ["10.0.2.0/24"]
}

variable "jumpbox_subnet_space" {
  type        = list(string)
  description = "Address space of the Jumpbox subnet"
  default     = ["10.0.3.0/24"]
}

variable "azfw_subnet_space" {
  type        = list(string)
  description = "Address space of the azfw subnet"
  default     = ["10.0.4.0/26"]
}

# Jumpbox
variable "log-export-jumpbox_name" {
  type        = string
  description = "Name of jumpbox vm"
  default     = "logxportjumpbox"
}
variable "log-export-jumpbox-admin" {
  type        = string
  description = "Admin username of jumpbox vm"
  default     = "exportadmin"
}

variable "log-export-jumpbox-admin-pw" {
  type        = string
  description = "Password for the admin username of jumpbox vm"
  default     = "ChangeMe123!"
  sensitive   = true
}
