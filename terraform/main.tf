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
  default     = ""
}

variable "resource_group_name" {
  default = "<your-rg-name>"
  type    = string

}

#---------------------------
# Virtual Network /  Subnet / NSG
#---------------------------
resource "azurerm_virtual_network" "log-export-vnet" {
  name                = "${var.project}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "log-export-subnet" {
  name                 = "${var.project}-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "azurerm_network_security_group" "log-export-nsg" {
  name                = "${var.project}-subnet-nsg"
  location            = azurerm_resource_group.example.location
  resource_group_name = azurerm_resource_group.example.name

  security_rule {
    name                       = "test123"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}

#---------------------------
# Application Insights
#---------------------------
resource "azurerm_application_insights" "log-export-insights" {
  name                = "${var.project}-insights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

#---------------------------
# Key Vault
#---------------------------
resource "azurerm_key_vault" "example" {
  name                     = "${var.project}-keyvault"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = true
}

#---------------------------
# Storage Account
#---------------------------
resource "azurerm_storage_account" "log-export-storage" {
  name                     = "${var.project}-storage"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  allow_nested_items_to_be_public = true
  min_tls_version                 = "TLS1_2"

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
  resource_group_name = var.resource_group_name
  location            = var.location
}

resource "azurerm_machine_learning_workspace" "workspace" {
  name                          = "${var.project}-mlw"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  public_network_access_enabled = false
  application_insights_id       = ""
  storage_account_id            = azurerm_storage_account.log-export-storage.id
  key_vault_id                  = ""

  identity {
    type = "SystemAssigned"
  }
  sku_name = "Basic"
}

resource "azurerm_machine_learning_compute_instance" "compute" {
  name                          = "${var.project}-mlw-compute"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  machine_learning_workspace_id = azurerm_machine_learning_workspace.workspace.id
  virtual_machine_size          = "Standard_D8s_v3"
  subnet_resource_id            = azurerm_subnet.subnet.id

  assign_to_user {
    object_id = "<YOUR_USER_OBJECT_ID>" # Replace with the user running jobs
    tenant_id = "<YOUR_TENANT_ID>"
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aml_identity.id]
  }
}
