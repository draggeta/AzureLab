resource "azurerm_public_ip" "hub_bastion" {
  name                = "${azurerm_resource_group.hub.name}-bastion-01-pi4-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_bastion_host" "hub_bastion" {
  name                = "${azurerm_resource_group.hub.name}-bastion-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  ip_configuration {
    name                 = "ipConfig1"
    subnet_id            = azurerm_subnet.hub_bastion_subnet.id
    public_ip_address_id = azurerm_public_ip.hub_bastion.id
  }

  sku                = "Basic"
  copy_paste_enabled = true
}
