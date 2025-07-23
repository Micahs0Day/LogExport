# #---------------------------
# # Jumpbox
# #---------------------------
# resource "azurerm_network_interface" "logexport-jumpbox-nic" {
#   name                = "nic-${var.log-export-jumpbox_name}-${random_string.suffix.result}"
#   location            = var.location
#   resource_group_name = var.resource_group_name

#   ip_configuration {
#     name                          = "configuration"
#     subnet_id                     = azurerm_subnet.log-export-subnet.id
#     private_ip_address_allocation = "Dynamic"
#   }
# }

# resource "azurerm_windows_virtual_machine" "logexportjumpbox" {
#   name                = var.log-export-jumpbox_name
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   network_interface_ids = [
#     azurerm_network_interface.logexport-jumpbox-nic.id
#   ]
#   size = "Standard_DS3_v2"

#   source_image_reference {
#     publisher = "MicrosoftWindowsDesktop"
#     offer     = "windows-11"
#     sku       = "win11-24h2-avd"
#     version   = "latest"
#   }

#   os_disk {
#     name                 = "osdisk-${var.log-export-jumpbox_name}"
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   identity {
#     type         = "UserAssigned"
#     identity_ids = [var.managed_identity]
#   }

#   computer_name  = var.log-export-jumpbox_name
#   admin_username = var.log-export-jumpbox-admin
#   admin_password = var.jumpboxpw

#   provision_vm_agent = true

#   timeouts {
#     create = "60m"
#     delete = "2h"
#   }
# }