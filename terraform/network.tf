#-------------------------------------
# Virtual Network / Subnet / Firewall
#-------------------------------------

# --- VNET --- #
resource "azurerm_virtual_network" "log-export-vnet" {
  name                = "${var.project}-vnet-${random_string.suffix.result}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
}

# --- Workspace VNET Subnet --- #
resource "azurerm_subnet" "log-export-subnet" {
  name                              = "${var.project}-subnet-${random_string.suffix.result}"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.log-export-vnet.name
  address_prefixes                  = var.mlw_subnet_space
  private_endpoint_network_policies = "Enabled"
}

# --- Firewall VNET Subnet --- #
resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.log-export-vnet.name
  address_prefixes     = var.azfw_subnet_space
}

# --- Bastion VNET Subnet --- #
resource "azurerm_subnet" "log-export-azure-bastion-subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.log-export-vnet.name
  address_prefixes     = var.bastion_subnet_space
}

# --- Jumpbox VNET Subnet --- #
resource "azurerm_subnet" "log-export-jumpbox-subnet" {
  name                              = "log-export-jumpbox-subnet"
  resource_group_name               = var.resource_group_name
  virtual_network_name              = azurerm_virtual_network.log-export-vnet.name
  address_prefixes                  = var.jumpbox_subnet_space
  private_endpoint_network_policies = "Enabled"
}

#----------------------
# DNS Zones
#----------------------

# --- Key Vault Zone --- #
resource "azurerm_private_dns_zone" "kv-dns-zone" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-link-vnet-kv" {
  name                  = "dnsvaultlink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv-dns-zone.name
  virtual_network_id    = azurerm_virtual_network.log-export-vnet.id
}

# --- Storage Account Zone (Blob) --- #
resource "azurerm_private_dns_zone" "sa-dns-blob-zone" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-link-vnet-sa-blob" {
  name                  = "dnsblobstoragelink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sa-dns-blob-zone.name
  virtual_network_id    = azurerm_virtual_network.log-export-vnet.id
}

# --- Storage Account Zone (File) --- #
resource "azurerm_private_dns_zone" "sa-dns-file-zone" {
  name                = "privatelink.file.core.windows.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-link-vnet-sa-file" {
  name                  = "dnsfilestoragelink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.sa-dns-file-zone.name
  virtual_network_id    = azurerm_virtual_network.log-export-vnet.id
}

# --- ML Workspace Zone --- #
resource "azurerm_private_dns_zone" "mlw-dns-zone" {
  name                = "privatelink.api.azureml.ms"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-link-vnet-mlw" {
  name                  = "dnsmlworkspacelink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.mlw-dns-zone.name
  virtual_network_id    = azurerm_virtual_network.log-export-vnet.id
}

# --- ML Notebook Zone --- #
resource "azurerm_private_dns_zone" "nbk-dns-zone" {
  name                = "privatelink.notebooks.azure.net"
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns-link-vnet-nbk" {
  name                  = "dnsnotebookslink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.nbk-dns-zone.name
  virtual_network_id    = azurerm_virtual_network.log-export-vnet.id
}

#----------------------
# Private Endpoint(s)
#----------------------

# --- Key Vault PLE --- #
resource "azurerm_private_endpoint" "ple-kv" {
  name                = "${var.project}-ple-kv-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.log-export-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv-dns-zone.id]
  }

  private_service_connection {
    name                           = "${var.project}-psc-kv-${random_string.suffix.result}"
    private_connection_resource_id = azurerm_key_vault.log-export-kv.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }
}

# --- Storage Account PLE (BLOB) --- #
resource "azurerm_private_endpoint" "ple-sa" {
  name                = "${var.project}-ple-sa-blob-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.log-export-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sa-dns-blob-zone.id]
  }

  private_service_connection {
    name                           = "${var.project}-psc-sa-blob-${random_string.suffix.result}"
    private_connection_resource_id = azurerm_storage_account.log-export-storage.id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }
}

# --- Storage Account PLE (FILE) --- #
resource "azurerm_private_endpoint" "storage_ple_file" {
  name                = "${var.project}-ple-sa-file-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.log-export-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sa-dns-file-zone.id]
  }

  private_service_connection {
    name                           = "${var.project}-psc-sa-file-${random_string.suffix.result}"
    private_connection_resource_id = azurerm_storage_account.log-export-storage.id
    subresource_names              = ["file"]
    is_manual_connection           = false
  }
}

# --- ML Workspace PLE --- #
resource "azurerm_private_endpoint" "ple-mlw" {
  name                = "${var.project}-ple-mlw-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = azurerm_subnet.log-export-subnet.id

  private_dns_zone_group {
    name                 = "private-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.mlw-dns-zone.id, azurerm_private_dns_zone.nbk-dns-zone.id]
  }

  private_service_connection {
    name                           = "${var.project}-psc-mlw-${random_string.suffix.result}"
    private_connection_resource_id = azurerm_machine_learning_workspace.log-export-mlw.id
    subresource_names              = ["amlworkspace"]
    is_manual_connection           = false
  }
}
