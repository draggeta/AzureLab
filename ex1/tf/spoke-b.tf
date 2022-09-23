resource "azurerm_resource_group" "spoke_b" {
  name     = "${var.secondary_prefix}-${var.org}-spoke-b-01"
  location = var.secondary_location
}

resource "azurerm_virtual_network" "spoke_b" {
  name                = "${azurerm_resource_group.spoke_b.name}-vnet-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name
  address_space       = ["10.130.0.0/16"]

  tags = var.tags
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "spoke_b_to_hub" {
  name                         = "peering-to-${azurerm_virtual_network.hub.name}"
  resource_group_name          = azurerm_virtual_network.spoke_b.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke_b.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  allow_gateway_transit = false
}
