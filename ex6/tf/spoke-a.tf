resource "azurerm_resource_group" "spoke_a" {
  name     = "${var.prefix}-${var.org}-spoke-a-01"
  location = var.primary_location
}

resource "azurerm_virtual_network" "spoke_a" {
  name                = "${azurerm_resource_group.spoke_a.name}-vnet-01"
  location            = azurerm_resource_group.spoke_a.location
  resource_group_name = azurerm_resource_group.spoke_a.name
  address_space       = ["10.129.0.0/16"]
  dns_servers         = [azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address]

  tags = var.tags
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "spoke_a_to_hub" {
  name                         = "peering-to-${azurerm_virtual_network.hub.name}"
  resource_group_name          = azurerm_virtual_network.spoke_a.resource_group_name
  virtual_network_name         = azurerm_virtual_network.spoke_a.name
  remote_virtual_network_id    = azurerm_virtual_network.hub.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  allow_gateway_transit = false
  use_remote_gateways   = true

  depends_on = [
    azurerm_virtual_network_gateway.hub_vpngw
  ]
}
