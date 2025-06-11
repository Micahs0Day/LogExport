# main.tf

provider "azurerm" {
  features {}
}

#---------------------------
# Variables
#---------------------------
variable "location" {
  default = "eastus"
}

variable "project" {
  default = "log-export"
}

variable "allowed_ip" {
  description = "The external IP address allowed to access the storage account."
  type        = string
}

#---------------------------
# Resource Group
#---------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.project}-rg"
  location = var.location
}

#---------------------------
# Virtual Network and Subnet
#---------------------------
resource "azurerm_virtual_network" "vnet" {
  name                = "${var.project}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "subnet" {
  name                 = "compute-subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#---------------------------
# Storage Account
#---------------------------
resource "azurerm_storage_account" "logstore" {
  name                     = "${var.project}store${random_id.suffix.hex}"
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  allow_blob_public_access = false
  min_tls_version          = "TLS1_2"

  network_rules {
    default_action             = "Deny"
    ip_rules                   = [var.allowed_ip]
    virtual_network_subnet_ids = [azurerm_subnet.subnet.id]
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }

  tags = {
    environment = "prod"
    project     = var.project
  }
}

resource "random_id" "suffix" {
  byte_length = 4
}

#---------------------------
# AML Compute Instance
#---------------------------
resource "azurerm_user_assigned_identity" "aml_identity" {
  name                = "${var.project}-aml-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
}

resource "azurerm_machine_learning_workspace" "workspace" {
  name                = "${var.project}-mlw"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name

  identity {
    type = "SystemAssigned"
  }
  sku_name = "Basic"
}

resource "azurerm_machine_learning_compute_instance" "compute" {
  name                         = "log-export-compute"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.main.name
  machine_learning_workspace_id = azurerm_machine_learning_workspace.workspace.id
  virtual_machine_size         = "Standard_D8s_v3"
  subnet_resource_id           = azurerm_subnet.subnet.id

  assign_to_user {
    object_id = "<YOUR_USER_OBJECT_ID>" # Replace with the user running jobs
    tenant_id = "<YOUR_TENANT_ID>"
  }

  identity {
    type = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aml_identity.id]
  }
}
