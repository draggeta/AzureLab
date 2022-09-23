resource "azurerm_subnet" "spoke_a_agw_subnet" {
  name                 = "ApplicationGatewaySubnet"
  resource_group_name  = azurerm_resource_group.spoke_a.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.129.4.0/24"]
}

resource "azurerm_public_ip" "spoke_a_agw" {
  name                = "${var.prefix}-${var.org}-spoke-a-01-agw-01-pi4-01"
  resource_group_name = azurerm_resource_group.spoke_a.name
  location            = azurerm_resource_group.spoke_a.location
  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label = "${var.prefix}-${var.org}-spoke-a-01-agw-01-pi4-01-${random_id.unique.hex}"
}

resource "azurerm_application_gateway" "spoke_a_agw" {
  name                = "${var.prefix}-${var.org}-spoke-a-01-agw-01"
  resource_group_name = azurerm_resource_group.spoke_a.name
  location            = azurerm_resource_group.spoke_a.location

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 1
  }

  gateway_ip_configuration {
    name      = "gatewayIPConfig"
    subnet_id = azurerm_subnet.spoke_a_agw_subnet.id
  }

  frontend_port {
    name = "fp-http"
    port = 80
  }

  frontend_ip_configuration {
    name                          = "fip-spoke-a"
    public_ip_address_id          = azurerm_public_ip.spoke_a_agw.id
    private_ip_address_allocation = "Dynamic"
  }

  backend_address_pool {
    name = "bp-spoke-a"
  }

  backend_http_settings {
    name                                = "bh-spoke-a"
    cookie_based_affinity               = "Disabled"
    pick_host_name_from_backend_address = true
    port                                = 80
    protocol                            = "Http"
    request_timeout                     = 60
  }

  probe {
    name                                      = "pb-health"
    protocol                                  = "Http"
    pick_host_name_from_backend_http_settings = true
    path                                      = "/health/"
    timeout                                   = 1
    interval                                  = 5
    unhealthy_threshold                       = 1
    minimum_servers                           = 1

    match {
      body        = "{\"health\": \"ok\"}"
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "ls-spoke-a"
    frontend_ip_configuration_name = "fip-spoke-a"
    frontend_port_name             = "fp-http"
    protocol                       = "Http"
  }

  request_routing_rule {
    priority                   = 100
    name                       = "rrr-spoke-a"
    rule_type                  = "Basic"
    http_listener_name         = "ls-spoke-a"
    backend_address_pool_name  = "bp-spoke-a"
    backend_http_settings_name = "bh-spoke-a"
  }
}

resource "azurerm_network_interface_application_gateway_backend_address_pool_association" "spoke_a_web_to_spoke_a_agw" {
  network_interface_id    = azurerm_network_interface.spoke_a_web.id
  ip_configuration_name   = azurerm_network_interface.spoke_a_web.ip_configuration[0].name
  backend_address_pool_id = tolist(azurerm_application_gateway.spoke_a_agw.backend_address_pool).0.id
}

resource "azurerm_monitor_diagnostic_setting" "spoke_a_agw" {
  # log_analytics_destination_type = "AzureDiagnostics" # Dedicated
  name               = "${azurerm_application_gateway.spoke_a_agw.name}-logdata-01"
  target_resource_id = azurerm_application_gateway.spoke_a_agw.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.net_watch_pri.id
  storage_account_id         = azurerm_storage_account.net_watch_pri.id

  log {
    category = "ApplicationGatewayAccessLog"
    enabled  = true

    retention_policy {
      days    = 90
      enabled = true
    }
  }
  log {
    category = "ApplicationGatewayPerformanceLog"
    enabled  = true

    retention_policy {
      days    = 90
      enabled = true
    }
  }
  log {
    category = "ApplicationGatewayFirewallLog"
    enabled  = true

    retention_policy {
      days    = 90
      enabled = true
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      days    = 90
      enabled = true
    }
  }
}
