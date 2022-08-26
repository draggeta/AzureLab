resource "azurerm_ip_group" "hub_management" {
  name                = "ipg-hub-management"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  cidrs = ["10.128.5.0/24"]

  tags = var.tags
}
resource "azurerm_ip_group" "spoke_a_web" {
  name                = "ipg-spoke-a-webserver"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  cidrs = ["10.129.5.0/24"]

  tags = var.tags
}
resource "azurerm_ip_group" "spoke_b_web" {
  name                = "ipg-spoke-b-webserver"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  cidrs = ["10.130.5.0/24"]

  tags = var.tags
}
