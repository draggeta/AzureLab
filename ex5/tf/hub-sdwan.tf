resource "azurerm_subnet" "hub_sdwan" {
  name                 = "sdwan"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.6.0/24"]
}

resource "azurerm_subnet_nat_gateway_association" "hub_ngw_to_hub_sdwan" {
  subnet_id      = azurerm_subnet.hub_sdwan.id
  nat_gateway_id = azurerm_nat_gateway.hub_ngw.id
}

resource "azurerm_network_security_group" "hub_sdwan" {
  name                = "${azurerm_virtual_network.hub.name}-sdwan-nsg-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  security_rule {
    name                       = "AllowAny"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "hub_sdwan_to_hub_sdwan" {
  subnet_id                 = azurerm_subnet.hub_sdwan.id
  network_security_group_id = azurerm_network_security_group.hub_sdwan.id
}

resource "azurerm_network_interface" "hub_sdwan" {
  name                = "sdwan01-nic-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.hub_sdwan.id
    private_ip_address_allocation = "Dynamic"
  }
  enable_ip_forwarding = true

}

resource "azurerm_linux_virtual_machine" "hub_sdwan" {
  name                  = "sdwan01"
  location              = azurerm_resource_group.hub.location
  resource_group_name   = azurerm_resource_group.hub.name
  network_interface_ids = [azurerm_network_interface.hub_sdwan.id]
  size                  = "Standard_B1s"

  zone = 1

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name    = "sdwan01-os-disk"
    caching = "ReadWrite"
    # create_option        = "FromImage"
    storage_account_type = "StandardSSD_LRS"
  }

  computer_name                   = "sdwan01"
  disable_password_authentication = false
  admin_username                  = var.credentials["username"]
  admin_password                  = var.credentials["password"]

  boot_diagnostics {}

  custom_data = base64encode(
    templatefile(
      "data/cloud-init.yml.j2",
      {
        rs_peer_1 = "10.128.2.4",
        rs_peer_2 = "10.128.2.5"
      }
    )
  )

  depends_on = [
    azurerm_firewall.hub_firewall,
    azurerm_firewall_policy_rule_collection_group.hub_firewall_default,
    azurerm_subnet_nat_gateway_association.hub_ngw_to_hub_sdwan,
  ]

  tags = var.tags
}
