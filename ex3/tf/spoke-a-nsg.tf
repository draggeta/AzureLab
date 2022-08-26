resource "azurerm_application_security_group" "spoke_a_web" {
  name                = "webservers-primary"
  location            = azurerm_resource_group.spoke_a.location
  resource_group_name = azurerm_resource_group.spoke_a.name
}

resource "azurerm_network_interface_application_security_group_association" "spoke_a_web" {
  network_interface_id          = azurerm_network_interface.spoke_a_web.id
  application_security_group_id = azurerm_application_security_group.spoke_a_web.id
}

resource "azurerm_network_security_group" "spoke_a_web" {
  name                = "${azurerm_virtual_network.spoke_a.name}-web-nsg-01"
  location            = azurerm_resource_group.spoke_a.location
  resource_group_name = azurerm_resource_group.spoke_a.name

  security_rule {
    name                                       = "AllowSshInbound"
    priority                                   = 100
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = [22]
    source_address_prefixes                    = [azurerm_network_interface.hub_management.private_ip_address]
    destination_application_security_group_ids = [azurerm_application_security_group.spoke_a_web.id]
  }
  security_rule {
    name                                       = "AllowRdpInbound"
    priority                                   = 200
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = [3389]
    source_address_prefixes                    = [azurerm_network_interface.hub_management.private_ip_address]
    destination_application_security_group_ids = [azurerm_application_security_group.spoke_a_web.id]
  }
  security_rule {
    name                                       = "AllowHttpInbound"
    priority                                   = 300
    direction                                  = "Inbound"
    access                                     = "Allow"
    protocol                                   = "Tcp"
    source_port_range                          = "*"
    destination_port_ranges                    = [80]
    source_address_prefix                      = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.spoke_a_web.id]
  }
  security_rule {
    name                                       = "DenyAnyInbound"
    priority                                   = 3000
    direction                                  = "Inbound"
    access                                     = "Deny"
    protocol                                   = "*"
    source_port_range                          = "*"
    destination_port_range                     = "*"
    source_address_prefix                      = "*"
    destination_application_security_group_ids = [azurerm_application_security_group.spoke_a_web.id]
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke_a_web_to_spoke_a_web" {
  subnet_id                 = azurerm_subnet.spoke_a_web.id
  network_security_group_id = azurerm_network_security_group.spoke_a_web.id
}
