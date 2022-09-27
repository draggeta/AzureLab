resource "azurerm_resource_group" "tm" {
  name     = "${var.prefix}-${var.org}-traffic-manager-01"
  location = var.primary_location
}

resource "azurerm_traffic_manager_profile" "tm" {
  name                   = "${var.prefix}-${var.org}-tm-01"
  resource_group_name    = azurerm_resource_group.tm.name
  traffic_routing_method = "Priority"

  dns_config {
    relative_name = "${var.prefix}-${var.org}-tm-01-${random_id.unique.hex}"
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/health/"
    interval_in_seconds          = 10
    timeout_in_seconds           = 5
    tolerated_number_of_failures = 1
  }

  traffic_view_enabled = true

  tags = var.tags
}

resource "azurerm_traffic_manager_nested_endpoint" "tm_nested_pri" {
  name               = "primary"
  target_resource_id = azurerm_traffic_manager_profile.tm_nested_pri.id
  priority           = 100
  profile_id         = azurerm_traffic_manager_profile.tm.id

  minimum_child_endpoints = 1
}

# resource "azurerm_traffic_manager_azure_endpoint" "spoke_b" {
#   name               = "secondary"
#   profile_id         = azurerm_traffic_manager_profile.tm.id
#   priority           = 120
#   target_resource_id = azurerm_public_ip.hub_firewall.id
# }

resource "azurerm_traffic_manager_profile" "tm_nested_pri" {
  name                   = "${var.prefix}-${var.org}-tm-primary-01"
  resource_group_name    = azurerm_resource_group.tm.name
  traffic_routing_method = "Weighted"

  dns_config {
    relative_name = "${var.prefix}-${var.org}-tm-primary-01-${random_id.unique.hex}"
    ttl           = 30
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/health/"
    interval_in_seconds          = 10
    timeout_in_seconds           = 5
    tolerated_number_of_failures = 1
  }

  traffic_view_enabled = true

  tags = var.tags
}

# resource "azurerm_traffic_manager_azure_endpoint" "spoke_a" {
#   name               = "spoke-a"
#   profile_id         = azurerm_traffic_manager_profile.tm_nested_pri.id
#   weight             = 100
#   target_resource_id = azurerm_public_ip.spoke_a_agw.id
# }

resource "azurerm_traffic_manager_external_endpoint" "on_prem" {
  name       = "on-prem"
  profile_id = azurerm_traffic_manager_profile.tm_nested_pri.id
  weight     = 100
  target     = azurerm_public_ip.op_fw.fqdn
}
