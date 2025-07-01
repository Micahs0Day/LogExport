#---------------------------
# Variables
#---------------------------
variable "location" {
  default = "eastus"
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

variable "allowed_external_ip" {
  description = "The external IP address allowed to access the storage account."
  type        = string
  default     = ""
}

variable "mlw_subnet_space" {
  type        = list(string)
  description = "IPv4 space of the ML workspace subnet"
  default     = ["10.0.0.0/24"]
}

variable "vnet_address_space" {
  type        = list(string)
  description = "IPv4 space of the virtual network"
  default     = ["10.0.0.0/16"]
}

variable "resource_group_name" {
  default = ""
  type    = string
}

variable "bastion_subnet_address_space" {
  type        = list(string)
  description = "Address space of the bastion subnet"
  default     = ["10.0.5.0/24"]
}

variable "jumpbox_subnet_address_space" {
  type        = list(string)
  description = "Address space of the Jumpbox subnet"
  default     = ["10.0.4.0/24"]
}

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
