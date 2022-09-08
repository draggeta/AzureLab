# resource "azurerm_route_table" "hub_firewall" {
#   name                = "${var.prefix}-${var.org}-udr-hub-firewall-01"
#   location            = azurerm_resource_group.hub.location
#   resource_group_name = azurerm_resource_group.hub.name

#   route {
#     name           = "internet"
#     address_prefix = "0.0.0.0/0"
#     next_hop_type  = "Internet"
#     # next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
#   }

#   route {
#     name           = "spoke-b-elb"
#     address_prefix = "${azurerm_public_ip.spoke_b_web_lb.ip_address}/32"
#     next_hop_type  = "Internet"
#   }
# }

# resource "azurerm_subnet_route_table_association" "hub_firewall" {
#   subnet_id      = azurerm_subnet.hub_firewall_subnet.id
#   route_table_id = azurerm_route_table.hub_firewall.id
# }

resource "azurerm_route_table" "hub" {
  name                = "${var.prefix}-${var.org}-udr-hub-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  route {
    name                   = "internet"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
  }

  route {
    name                   = "sd-wan"
    address_prefix         = "10.192.0.0/21"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.hub_sdwan.frontend_ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "hub_management" {
  subnet_id      = azurerm_subnet.hub_management.id
  route_table_id = azurerm_route_table.hub.id
}

resource "azurerm_route_table" "spoke_a" {
  name                = "${var.secondary_prefix}-${var.org}-udr-spoke-01"
  location            = azurerm_resource_group.spoke_a.location
  resource_group_name = azurerm_resource_group.spoke_a.name

  route {
    name                   = "internal"
    address_prefix         = "10.128.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
  }
  route {
    name                   = "internet"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
  }
  route {
    name                   = "sd-wan"
    address_prefix         = "10.192.0.0/21"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.hub_sdwan.frontend_ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "spoke_a_web" {
  subnet_id      = azurerm_subnet.spoke_a_web.id
  route_table_id = azurerm_route_table.spoke_a.id
}

resource "azurerm_route_table" "spoke_b" {
  name                = "${var.secondary_prefix}-${var.org}-udr-spoke-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name

  route {
    name                   = "internal"
    address_prefix         = "10.128.0.0/14"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
  }
  route {
    name                   = "internet"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.hub_firewall.ip_configuration[0].private_ip_address
  }
  route {
    name                   = "sd-wan"
    address_prefix         = "10.192.0.0/21"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_lb.hub_sdwan.frontend_ip_configuration[0].private_ip_address
  }

  route {
    name           = "firewall-public-ip"
    address_prefix = azurerm_public_ip.hub_firewall.ip_address
    next_hop_type  = "Internet"
  }
}

resource "azurerm_subnet_route_table_association" "spoke_b_web" {
  subnet_id      = azurerm_subnet.spoke_b_web.id
  route_table_id = azurerm_route_table.spoke_b.id
}
