resource "azurerm_application_security_group" "hub_management" {
  name                = "managementservers"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
}

resource "azurerm_network_interface_application_security_group_association" "hub_management" {
  network_interface_id          = azurerm_network_interface.hub_management.id
  application_security_group_id = azurerm_application_security_group.hub_management.id
}

resource "azurerm_network_security_group" "hub_management" {
  name                = "${azurerm_virtual_network.hub.name}-management-nsg-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  security_rule {
    name                       = "AllowRdpInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = [3389]
    source_address_prefixes    = [azurerm_subnet.hub_bastion_subnet.address_prefixes[0]]
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "DenyAnyInbound"
    priority                   = 3000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAppServiceWeuOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AppService.WestEurope"
  }
  security_rule {
    name                       = "DenyAppServiceOutbound"
    priority                   = 200
    direction                  = "Outbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "AppService"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "hub_management_to_hub_management" {
  subnet_id                 = azurerm_subnet.hub_management.id
  network_security_group_id = azurerm_network_security_group.hub_management.id
}
