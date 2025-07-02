resource "azurerm_firewall_policy" "logexportfwpolicy" {
  name                = "logexportfwpolicy${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns {
    proxy_enabled = true
  }
}

resource "azurerm_firewall_policy_rule_collection_group" "logexportfwpolicygroup" {
  depends_on         = [azurerm_firewall.logexportazfw]
  firewall_policy_id = azurerm_firewall_policy.logexportfwpolicy.id
  priority           = 100
  name               = "logexport-azfw-rcgroup-${random_string.suffix.result}"

  network_rule_collection {
    name     = "req_egress_netwrk_${random_string.suffix.result}"
    priority = 100
    action   = "Allow"

    # MLW Required Outbound (AzureActiveDirectory)
    rule {
      name                  = "req_network_egress_rule1"
      source_addresses      = var.mlw_subnet_space
      destination_ports     = ["443"]
      destination_addresses = ["AzureActiveDirectory"]
      protocols             = ["TCP"]
    }

    # MLW Required Outbound (AzureMachineLearning TCP)
    rule {
      name                  = "req_network_egress_rule2"
      source_addresses      = var.mlw_subnet_space
      destination_ports     = ["443", "18881"]
      destination_addresses = ["AzureMachineLearning"]
      protocols             = ["TCP"]
    }

    # MLW Required Outbound (AzureMachineLearning UDP)
    rule {
      name                  = "req_network_egress_rule3"
      source_addresses      = var.mlw_subnet_space
      destination_ports     = ["5831"]
      destination_addresses = ["AzureMachineLearning"]
      protocols             = ["UDP"]
    }

    # MLW Required Outbound (Batch Node Management)
    rule {
      name                  = "req_network_egress_rule4"
      source_addresses      = var.mlw_subnet_space
      destination_ports     = ["443"]
      destination_addresses = ["BatchNodeManagement.eastus"]
      protocols             = ["Any"]
    }

    # MLW Required Outbound (General)
    rule {
      name                  = "req_network_egress_rule5"
      protocols             = ["TCP"]
      source_addresses      = var.mlw_subnet_space
      destination_addresses = ["AzureResourceManager", "Storage.eastus", "AzureFrontDoor.FrontEnd"]
      destination_ports     = ["443"]
    }

    # Storage Account to External (Outbound)
    rule {
      name                  = "req_network_egress_rule6"
      source_addresses      = var.mlw_subnet_space
      destination_addresses = var.external_ips
      destination_ports     = ["443"]
      protocols             = ["TCP"]
    }

    # External to Storage Account (Inbound)
    rule {
      name                  = "req_network_ingress_rule1"
      source_addresses      = var.external_ips
      destination_addresses = var.mlw_subnet_space
      destination_ports     = ["443"]
      protocols             = ["TCP"]
    }
  }

  application_rule_collection {
    name     = "req_app_egress_${random_string.suffix.result}"
    priority = 101
    action   = "Allow"

    # MLW Package Installation
    rule {
      name              = "req_app_egress_rule1"
      source_addresses  = var.mlw_subnet_space
      destination_fqdns = ["anaconda.com", "*.anaconda.com", "*.anaconda.org", "pypi.org", "pypi.python.org"]
      protocols {
        type = "Https"
        port = 443
      }
    }

  }
}

resource "azurerm_public_ip" "logexport-azfwip" {
  name                = "logexport-azfwip-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "logexportazfw" {
  name                = "logexport-azfw-${random_string.suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"
  ip_configuration {
    name                 = "azfw-ipconfig"
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.logexport-azfwip.id
  }
  firewall_policy_id = azurerm_firewall_policy.logexportfwpolicy.id
}
