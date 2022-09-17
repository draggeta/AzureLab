resource "azurerm_public_ip" "hub_rs" {
  name                = "${azurerm_resource_group.hub.name}-rs-01-pi4-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_route_server" "hub_rs" {
  name                             = "${azurerm_resource_group.hub.name}-rs-01"
  location                         = azurerm_resource_group.hub.location
  resource_group_name              = azurerm_resource_group.hub.name
  sku                              = "Standard"
  public_ip_address_id             = azurerm_public_ip.hub_rs.id
  subnet_id                        = azurerm_subnet.hub_routeserver_subnet.id
  branch_to_branch_traffic_enabled = false
}

resource "azurerm_route_server_bgp_connection" "hub_rs_to_hub_sdwan" {
  name            = azurerm_linux_virtual_machine.hub_sdwan.name
  route_server_id = azurerm_route_server.hub_rs.id
  peer_asn        = 65002
  peer_ip         = azurerm_network_interface.hub_sdwan.ip_configuration[0].private_ip_address
}
