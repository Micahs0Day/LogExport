#---------------------------
# Random suffix for uniqueness
#---------------------------

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
# Application Insights
#---------------------------
resource "azurerm_application_insights" "log-export-insights" {
  name                = "${var.project}-insights-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
}

#---------------------------
# Storage Account
#---------------------------

resource "azurerm_storage_account" "log-export-storage" {
  name                            = "logexportstorage${random_string.suffix.result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  allow_nested_items_to_be_public = true
  min_tls_version                 = "TLS1_2"

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.external_ips
  }

  blob_properties {
    delete_retention_policy {
      days = 7
    }
  }
}

data "azurerm_storage_account" "log-export-storage" {
  name                = azurerm_storage_account.log-export-storage.name
  resource_group_name = var.resource_group_name
}

#---------------------------
# Key Vault
#---------------------------
resource "azurerm_key_vault" "log-export-kv" {
  name                     = "${var.project}-keyvault-${random_string.suffix.result}"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "standard"
  purge_protection_enabled = true
  depends_on = [
    azurerm_storage_account.log-export-storage
  ]
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
  }

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

#---------------------------
# ML Workspace & Compute
#---------------------------

resource "azurerm_machine_learning_workspace" "log-export-mlw" {
  name                          = "${var.project}-mlw-${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  application_insights_id       = azurerm_application_insights.log-export-insights.id
  storage_account_id            = azurerm_storage_account.log-export-storage.id
  key_vault_id                  = azurerm_key_vault.log-export-kv.id
  public_network_access_enabled = false
  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_private_endpoint.ple-kv,
    azurerm_private_endpoint.ple-sa,
    azurerm_subnet.log-export-subnet
  ]
  sku_name = "Basic"
}

resource "azurerm_machine_learning_compute_instance" "mlw-compute" {
  name                          = "mlw-compute-${random_string.suffix.result}"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.log-export-mlw.id
  virtual_machine_size          = "Standard_D4s_v3"
  node_public_ip_enabled        = false
  authorization_type            = "personal"
  subnet_resource_id            = azurerm_subnet.log-export-subnet.id
  depends_on = [
    azurerm_private_endpoint.ple-mlw
  ]
}
