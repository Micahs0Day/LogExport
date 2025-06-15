#---------------------------
# Variables
#---------------------------
variable "location" {
  default = "eastus2"
}

variable "user_obj_id" {
  default = "<user_obj_id>"
}

variable "tenant_id" {
  default = "<tenant_id>"
}

variable "subscription_id" {
  default = "<subscription_id>"
}

variable "project" {
  default = "log-export"
}

variable "allowed_external_ip" {
  description = "The external IP address allowed to access the storage account."
  type        = string
  default     = "<allowed_external_ip>"
}

variable "allowed_ingress_ip" {
  description = "The IP address that will access the VM via SSH/HTTP(S)"
  type        = string
  default     = "<allowed_ingress_ip>"
}

variable "resource_group_name" {
  default = "<resource_group_name>"
  type    = string

}

variable "ssh_public_key_path" {
  default = "~/.ssh/id_rsa.pub"
}

locals {
  ssh_public_key = file(var.ssh_public_key_path)
}

# Random suffix for uniqueness
resource "random_string" "suffix" {
  length  = 4
  upper   = false
  special = false
}

#---------------------------
# Provider Config
#---------------------------

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

data "azurerm_client_config" "current" {
}

#---------------------------
# Storage Account
#---------------------------
resource "azurerm_storage_account" "log-export-storage" {
  name                     = "logexportstorage${random_string.suffix.result}1"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  public_network_access_enabled   = true
  allow_nested_items_to_be_public = true

  min_tls_version = "TLS1_2"

  network_rules {
    default_action             = "Deny"
    ip_rules                   = [var.allowed_external_ip]
    virtual_network_subnet_ids = [azurerm_subnet.log-export-subnet.id]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

}

data "azurerm_storage_account" "log_export_storage" {
  name                = azurerm_storage_account.log-export-storage.name
  resource_group_name = var.resource_group_name
}

#---------------------------
# Key Vault
#---------------------------
resource "azurerm_key_vault" "log_export_kv" {
  name                     = "${var.project}-kv${random_string.suffix.result}"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = true

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Decrypt",
      "Get",
      "Delete",
      "Import",
      "Verify",
      "Get",
      "List",
      "Sign",
      "Verify"
    ]

    secret_permissions = [
      "Get",
      "Set",
      "List",
      "Delete",
      "Recover",
      "Restore",
      "Backup",
      "Purge"
    ]
  }
}

resource "azurerm_key_vault_secret" "ssh_pubkey_secret" {
  name         = "ssh-pubkey"
  value        = local.ssh_public_key
  key_vault_id = azurerm_key_vault.log_export_kv.id
}

resource "azurerm_key_vault_secret" "storage_access_key" {
  name         = "storage-access-key"
  value        = data.azurerm_storage_account.log_export_storage.primary_access_key
  key_vault_id = azurerm_key_vault.log_export_kv.id
}

#---------------------------
# Network Config
#---------------------------
resource "azurerm_virtual_network" "log-export-vnet" {
  name                = "${var.project}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "log-export-subnet" {
  name                 = "${var.project}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.log-export-vnet.name
  service_endpoints    = ["Microsoft.Storage"]
  address_prefixes     = ["10.0.1.0/24"]
}

# Public IP for the VM
resource "azurerm_public_ip" "logexport_public_ip" {
  name                = "logexportpip-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Security Group
resource "azurerm_network_security_group" "logexport_nsg" {
  name                = "logexportnsg-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Ingress SSH
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ingress_ip
    destination_address_prefix = "*"
  }

  # Ingress HTTP
  security_rule {
    name                       = "HTTP"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.allowed_ingress_ip
    destination_address_prefix = "*"
  }

  # Ingress HTTPS
  security_rule {
    name                       = "HTTPS"
    priority                   = 1003
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.allowed_ingress_ip
    destination_address_prefix = "*"
  }

  # Internal Network Route Allow all
  security_rule {
    name                       = "Allow-Internal-VNet"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
}

#---------------------------
# Virtual Machine
#---------------------------

# Updated NIC with Public IP
resource "azurerm_network_interface" "log-export-nic" {
  name                = "logexportnic${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.log-export-subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.logexport_public_ip.id
  }

}

# Associate NSG to NIC directly
resource "azurerm_network_interface_security_group_association" "logexport_nsg_nic_assoc" {
  network_interface_id      = azurerm_network_interface.log-export-nic.id
  network_security_group_id = azurerm_network_security_group.logexport_nsg.id
}

resource "azurerm_linux_virtual_machine" "log-export-vm" {
  name                = "logexportvm${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_F2"
  admin_username      = "exportadmin"
  network_interface_ids = [
    azurerm_network_interface.log-export-nic.id,
  ]

  admin_ssh_key {
    username   = "exportadmin"
    public_key = azurerm_key_vault_secret.ssh_pubkey_secret.value
  }

custom_data = base64encode(file("${path.module}/jupyer_install.sh"))

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 200
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}
