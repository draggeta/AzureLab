resource "azurerm_resource_group" "ip_group" {
  name     = "${var.prefix}-${var.org}-ip-groups-01"
  location = var.primary_location
}

resource "azurerm_ip_group" "rfc1918" {
  name                = "ipg-rfc1918"
  location            = azurerm_resource_group.ip_group.location
  resource_group_name = azurerm_resource_group.ip_group.name

  cidrs = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

  tags = var.tags
}

resource "azurerm_ip_group" "supernet" {
  name                = "ipg-supernet"
  location            = azurerm_resource_group.ip_group.location
  resource_group_name = azurerm_resource_group.ip_group.name

  cidrs = ["10.128.0.0/14"]

  tags = var.tags
}

resource "azurerm_ip_group" "hub_management" {
  name                = "ipg-hub-management"
  location            = azurerm_resource_group.ip_group.location
  resource_group_name = azurerm_resource_group.ip_group.name

  cidrs = azurerm_subnet.hub_management.address_prefixes

  tags = var.tags
}

resource "azurerm_ip_group" "spoke_a_web" {
  name                = "ipg-spoke-a-webserver"
  location            = azurerm_resource_group.ip_group.location
  resource_group_name = azurerm_resource_group.ip_group.name

  cidrs = azurerm_subnet.spoke_a_web.address_prefixes

  tags = var.tags
}

resource "azurerm_ip_group" "spoke_b_web" {
  name                = "ipg-spoke-b-webserver"
  location            = azurerm_resource_group.ip_group.location
  resource_group_name = azurerm_resource_group.ip_group.name

  cidrs = azurerm_subnet.spoke_b_web.address_prefixes

  tags = var.tags
}
