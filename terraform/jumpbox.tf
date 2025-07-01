#---------------------------
# Bastion
#---------------------------

resource "azurerm_public_ip" "log-export-bastion-public-ip" {
  name                = "log-export-bastion"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_security_group" "log-export-bastion-nsg" {
  name                = "log-export-bastion-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowAzureLBInbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "AllowBastionHostCommunication"
    priority                   = 400
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["5701", "8080"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowRdpSshOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowBastionHostCommunicationOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["5701", "8080"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443"]
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }
  security_rule {
    name                       = "AllowGetSessionInformation"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["80"]
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

}

resource "azurerm_subnet_network_security_group_association" "log-export-bastion-nsg-assoc" {
  subnet_id                 = azurerm_subnet.azure_bastion.id
  network_security_group_id = azurerm_network_security_group.log-export-bastion-nsg.id
  depends_on = [
    azurerm_bastion_host.log-export-bastion-instance
  ]
}

resource "azurerm_bastion_host" "log-export-bastion-instance" {
  name                = "${var.project}-bastion-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.azure_bastion.id
    public_ip_address_id = azurerm_public_ip.log-export-bastion-public-ip.id
  }
}

#---------------------------
# Jumpbox
#---------------------------
resource "azurerm_network_interface" "logexport-jumpbox-nic" {
  name                = "nic-${var.log-export-jumpbox_name}-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "configuration"
    subnet_id                     = azurerm_subnet.log-export-jumpbox-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "logexportjumpbox" {
  name                = var.log-export-jumpbox_name
  location            = var.location
  resource_group_name = var.resource_group_name
  network_interface_ids = [
    azurerm_network_interface.logexport-jumpbox-nic.id
  ]
  size = "Standard_DS3_v2"

  source_image_reference {
    publisher = "microsoft-dsvm"
    offer     = "dsvm-win-2019"
    sku       = "server-2019"
    version   = "latest"
  }

  os_disk {
    name                 = "osdisk-${var.log-export-jumpbox_name}"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  identity {
    type = "SystemAssigned"
  }
  computer_name  = var.log-export-jumpbox_name
  admin_username = var.log-export-jumpbox-admin
  admin_password = var.log-export-jumpbox-admin-pw

  provision_vm_agent = true

  timeouts {
    create = "60m"
    delete = "2h"
  }
}
