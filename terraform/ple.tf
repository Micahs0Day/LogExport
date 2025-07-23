# Private endpoints
resource "azurerm_private_endpoint" "kv_ple" {
  name                = "ple-${var.project}-${random_string.suffix.result}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.mlws-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsvault.id]
  }

  private_service_connection {
    name                           = "psc-${var.project}-kv"
    private_connection_resource_id = azurerm_key_vault.log-export-kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "st_ple_blob" {
  name                = "ple-${var.project}-${random_string.suffix.result}-st-blob"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.mlws-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsstorageblob.id]
  }

  private_service_connection {
    name                           = "psc-${var.project}-st"
    private_connection_resource_id = azurerm_storage_account.mlwstorage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "storage_ple_file" {
  name                = "ple-${var.project}-${random_string.suffix.result}-st-file"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.mlws-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsstoragefile.id]
  }

  private_service_connection {
    name                           = "psc-${var.project}-st"
    private_connection_resource_id = azurerm_storage_account.mlwstorage.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
}

resource "azurerm_private_endpoint" "mlw_ple" {
  name                = "ple-${var.project}-${random_string.suffix.result}-mlw"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.mlws-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dnsazureml.id, azurerm_private_dns_zone.dnsnotebooks.id]
  }

  private_service_connection {
    name                           = "psc-${var.project}-mlw"
    private_connection_resource_id = azurerm_machine_learning_workspace.ml_workspace.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }
}
