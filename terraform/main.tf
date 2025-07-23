#---------------------------
# Random suffix for uniqueness
#---------------------------

resource "random_string" "suffix" {
  length  = 3
  upper   = false
  special = false
}

#---------------------------
# Provider Config
#---------------------------
terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.0, < 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.0"
    }
  }
}

provider "azurerm" {
  features {
    key_vault {
      recover_soft_deleted_key_vaults    = false
      purge_soft_delete_on_destroy       = false
      purge_soft_deleted_keys_on_destroy = false
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

data "azurerm_client_config" "current" {}

#---------------------------
# Storage Account
#---------------------------

resource "azurerm_storage_account" "mlwstorage" {
  name                            = "mlwstorage${random_string.suffix.result}"
  location                        = var.location
  resource_group_name             = var.resource_group_name
  account_tier                    = "Standard"
  account_replication_type        = "GRS"
  allow_nested_items_to_be_public = false

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = var.external_ips
  }
}


#---------------------------
# Key Vault
#---------------------------

resource "azurerm_key_vault" "log-export-kv" {
  name                     = "${var.project}-kvault-${random_string.suffix.result}"
  location                 = var.location
  resource_group_name      = var.resource_group_name
  tenant_id                = data.azurerm_client_config.current.tenant_id
  sku_name                 = "premium"
  purge_protection_enabled = true

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"
    ip_rules       = var.external_ips
  }
}

#---------------------------
# ML Workspace & Compute
#---------------------------

resource "azurerm_machine_learning_workspace" "ml_workspace" {
  name                          = "mlws${random_string.suffix.result}"
  location                      = var.location
  resource_group_name           = var.resource_group_name
  application_insights_id       = azurerm_application_insights.log-export-insights.id
  key_vault_id                  = azurerm_key_vault.log-export-kv.id
  storage_account_id            = azurerm_storage_account.mlwstorage.id
  public_network_access_enabled = true

  identity {
    type = "SystemAssigned"
  }

  depends_on = [
    azurerm_private_endpoint.kv_ple,
    azurerm_private_endpoint.st_ple_blob,
    azurerm_private_endpoint.storage_ple_file,
  ]

}

# Compute instance
resource "azurerm_machine_learning_compute_instance" "compute_instance" {
  name                          = "mlws2-compute-${random_string.suffix.result}"
  machine_learning_workspace_id = azurerm_machine_learning_workspace.ml_workspace.id
  virtual_machine_size          = "Standard_DS3_v2"
  subnet_resource_id            = azurerm_subnet.mlws-subnet.id
  authorization_type            = "personal"
  node_public_ip_enabled = false

  assign_to_user {
    object_id = var.user_obj-id
    tenant_id = var.tenant_id
  }

  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_private_endpoint.mlw_ple
  ]
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
