resource "azurerm_resource_group" "hub" {
  name     = "${var.prefix}-${var.org}-hub-01"
  location = var.primary_location
}

resource "azurerm_virtual_network" "hub" {
  name                = "${azurerm_resource_group.hub.name}-vnet-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  address_space       = ["10.128.0.0/16"]
  dns_servers         = ["10.128.1.4"]

  tags = var.tags
}

resource "azurerm_subnet" "hub_gateway_subnet" {
  name                 = "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.0.0/24"]
}
resource "azurerm_subnet" "hub_firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.1.0/24"]
}
resource "azurerm_subnet" "hub_routeserver_subnet" {
  name                 = "RouteServerSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.2.0/24"]
}
resource "azurerm_subnet" "hub_bastion_subnet" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.3.0/24"]
}
resource "azurerm_subnet" "hub_agw_subnet" {
  name                 = "ApplicationGatewaySubnet"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.4.0/24"]
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "hub_to_spoke_a" {
  name                         = "peering-to-${azurerm_virtual_network.spoke_a.name}"
  resource_group_name          = azurerm_virtual_network.hub.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_a.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = true
}

# enable global peering between the two virtual network
resource "azurerm_virtual_network_peering" "hub_to_spoke_b" {
  name                         = "peering-to-${azurerm_virtual_network.spoke_b.name}"
  resource_group_name          = azurerm_virtual_network.hub.resource_group_name
  virtual_network_name         = azurerm_virtual_network.hub.name
  remote_virtual_network_id    = azurerm_virtual_network.spoke_b.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true

  # `allow_gateway_transit` must be set to false for vnet Global Peering
  allow_gateway_transit = true
}
