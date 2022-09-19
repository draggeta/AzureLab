resource "azurerm_public_ip" "spoke_b_web_lb" {
  name                = "${var.secondary_prefix}-${var.org}-lb-web-01-pi4-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name

  sku               = "Standard"
  allocation_method = "Static"
  domain_name_label = "${var.secondary_prefix}-${var.org}-lb-web-01-${random_id.unique.hex}"
}

resource "azurerm_lb" "spoke_b_web_lb" {
  name                = "${var.secondary_prefix}-${var.org}-lb-web-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name

  sku = "Standard"

  frontend_ip_configuration {
    name                 = "ipConfig1"
    public_ip_address_id = azurerm_public_ip.spoke_b_web_lb.id
  }
}

resource "azurerm_lb_probe" "spoke_b_web_lb" {
  loadbalancer_id = azurerm_lb.spoke_b_web_lb.id
  name            = "probe-http"

  protocol            = "Http"
  request_path        = "/health/"
  port                = 80
  number_of_probes    = 2
  interval_in_seconds = 5
}

resource "azurerm_lb_backend_address_pool" "spoke_b_web_lb" {
  loadbalancer_id = azurerm_lb.spoke_b_web_lb.id
  name            = "bep-web"
}

resource "azurerm_network_interface_backend_address_pool_association" "spoke_b_web_lb" {
  network_interface_id    = azurerm_network_interface.spoke_b_web.id
  ip_configuration_name   = azurerm_network_interface.spoke_b_web.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.spoke_b_web_lb.id
}

resource "azurerm_lb_rule" "spoke_b_web_lb" {
  name            = "lbr-web"
  loadbalancer_id = azurerm_lb.spoke_b_web_lb.id

  frontend_ip_configuration_name = azurerm_lb.spoke_b_web_lb.frontend_ip_configuration[0].name
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.spoke_b_web_lb.id]
  probe_id                       = azurerm_lb_probe.spoke_b_web_lb.id

  frontend_port         = 80
  backend_port          = 80
  protocol              = "Tcp"
  enable_floating_ip    = false
  disable_outbound_snat = true
}

resource "azurerm_monitor_diagnostic_setting" "spoke_b_web_lb" {
  # log_analytics_destination_type = "AzureDiagnostics" # Dedicated
  name               = "${azurerm_lb.spoke_b_web_lb.name}-logdata-01"
  target_resource_id = azurerm_lb.spoke_b_web_lb.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.net_watch_pri.id
  storage_account_id         = azurerm_storage_account.net_watch_sec.id

  log {
    category = "LoadBalancerAlertEvent"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
  log {
    category = "LoadBalancerProbeHealthStatus"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
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
