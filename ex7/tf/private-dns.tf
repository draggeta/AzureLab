resource "azurerm_resource_group" "dns" {
  name     = "${var.prefix}-${var.org}-dns-01"
  location = var.primary_location
}

resource "azurerm_private_dns_zone" "priv_dns" {
  name                = "by.cloud"
  resource_group_name = azurerm_resource_group.dns.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "priv_dns_to_hub" {
  name                = "priv-dns-to-hub"
  resource_group_name = azurerm_private_dns_zone.priv_dns.resource_group_name

  private_dns_zone_name = azurerm_private_dns_zone.priv_dns.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = true
}
resource "azurerm_private_dns_zone_virtual_network_link" "priv_dns_to_spoke_a" {
  name                = "priv-dns-to-spoke-a"
  resource_group_name = azurerm_private_dns_zone.priv_dns.resource_group_name

  private_dns_zone_name = azurerm_private_dns_zone.priv_dns.name
  virtual_network_id    = azurerm_virtual_network.spoke_a.id
  registration_enabled  = true
}
resource "azurerm_private_dns_zone_virtual_network_link" "priv_dns_to_spoke_b" {
  name                = "priv-dns-to-spoke-b"
  resource_group_name = azurerm_private_dns_zone.priv_dns.resource_group_name

  private_dns_zone_name = azurerm_private_dns_zone.priv_dns.name
  virtual_network_id    = azurerm_virtual_network.spoke_b.id
  registration_enabled  = true
}

resource "azurerm_private_dns_cname_record" "tm" {
  name                = "api"
  zone_name           = azurerm_private_dns_zone.priv_dns.name
  resource_group_name = azurerm_private_dns_zone.priv_dns.resource_group_name
  ttl                 = 30
  record              = azurerm_traffic_manager_profile.tm.fqdn
}

# privateLink DNS
resource "azurerm_private_dns_zone" "priv_az_web" {
  name                = "privatelink.azurewebsites.net"
  resource_group_name = azurerm_resource_group.dns.name
}
resource "azurerm_private_dns_zone_virtual_network_link" "priv_az_web_to_hub" {
  name                = "priv-az-web-to-hub"
  resource_group_name = azurerm_private_dns_zone.priv_az_web.resource_group_name

  private_dns_zone_name = azurerm_private_dns_zone.priv_az_web.name
  virtual_network_id    = azurerm_virtual_network.hub.id
  registration_enabled  = false
}
