#---------------------------
# Virtual Network & Subnet
#---------------------------

resource "azurerm_virtual_network" "mlws-vnet" {
  name                = "vnet-${var.project_name}-${random_string.suffix.result}"
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "mlws-subnet" {
  name                                          = "mlws-${var.project_name}-${random_string.suffix.result}"
  resource_group_name                           = var.resource_group_name
  virtual_network_name                          = azurerm_virtual_network.mlws-vnet.name
  address_prefixes                              = var.mlw_subnet_space
  private_link_service_network_policies_enabled = true
}

#---------------------------
# User Defined Routes
#---------------------------

# UDR for MLW compute instance
resource "azurerm_route_table" "rt-mlws" {
  name                = "rt-mlws"
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_route" "mlws-Internet-Route" {
  name                = "Internet"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.rt-mlws.name
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "mlws-AzureMLRoute" {
  name                = "AzureMLRoute"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.rt-mlws.name
  address_prefix      = "AzureMachineLearning"
  next_hop_type       = "Internet"
}

resource "azurerm_route" "mlws-BatchRoute" {
  name                = "BatchRoute"
  resource_group_name = var.resource_group_name
  route_table_name    = azurerm_route_table.rt-mlws.name
  address_prefix      = "BatchNodeManagement"
  next_hop_type       = "Internet"
}

resource "azurerm_subnet_route_table_association" "rt-mlws-link" {
  subnet_id      = azurerm_subnet.mlws-subnet.id
  route_table_id = azurerm_route_table.rt-mlws.id
}