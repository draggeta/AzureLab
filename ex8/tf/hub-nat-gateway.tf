resource "azurerm_public_ip" "hub_ngw" {
  name                = "${azurerm_resource_group.hub.name}-ngw-01-pi4-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label = "${azurerm_resource_group.hub.name}-ngw-01-pi4-01-${random_id.unique.hex}"
}

resource "azurerm_nat_gateway_public_ip_association" "hub_ngw_to_hub_ngw" {
  nat_gateway_id       = azurerm_nat_gateway.hub_ngw.id
  public_ip_address_id = azurerm_public_ip.hub_ngw.id
}

resource "azurerm_nat_gateway" "hub_ngw" {
  name                    = "${azurerm_resource_group.hub.name}-ngw-01"
  location                = azurerm_resource_group.hub.location
  resource_group_name     = azurerm_resource_group.hub.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 10
}
