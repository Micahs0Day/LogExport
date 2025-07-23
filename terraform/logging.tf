#---------------------------
# Logging
#---------------------------

# Key Vault (Audit)
resource "azurerm_monitor_diagnostic_setting" "logexport-kv-logging" {
  name                       = "${var.project_name}-kv-logs-${random_string.suffix.result}"
  target_resource_id         = azurerm_key_vault.log-export-kv.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "AuditEvent"
  }
}

# Storage Account (Data)
resource "azurerm_monitor_diagnostic_setting" "logexport-blob-logging" {
  name                           = "${var.project_name}-blob-logs-${random_string.suffix.result}"
  target_resource_id             = "${azurerm_storage_account.mlwstorage.id}/blobServices/default"
  log_analytics_workspace_id     = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "StorageRead"
  }

  enabled_log {
    category = "StorageWrite"
  }

  enabled_log {
    category = "StorageDelete"
  }
}

# Application Insights (App)
resource "azurerm_application_insights" "log-export-insights" {
  name                = "${var.project_name}-insights-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = var.log_analytics_workspace_id
}