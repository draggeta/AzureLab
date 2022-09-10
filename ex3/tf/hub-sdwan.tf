resource "azurerm_subnet" "hub_sdwan" {
  name                 = "sdwan"
  resource_group_name  = azurerm_resource_group.hub.name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.128.6.0/24"]
}

resource "azurerm_network_interface" "hub_sdwan" {
  name                = "sdwan02-nic-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.hub_sdwan.id
    private_ip_address_allocation = "Dynamic"

    # public_ip_address_id          = azurerm_public_ip.sd_wan.id
  }
  enable_ip_forwarding = true

}

resource "azurerm_linux_virtual_machine" "hub_sdwan" {
  name                  = "sdwan02"
  location              = azurerm_resource_group.hub.location
  resource_group_name   = azurerm_resource_group.hub.name
  network_interface_ids = [azurerm_network_interface.hub_sdwan.id]
  size                  = "Standard_B2s"

  zone = 1

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name    = "sdwan02-os-disk"
    caching = "ReadWrite"
    # create_option        = "FromImage"
    storage_account_type = "StandardSSD_LRS"
  }

  computer_name                   = "sdwan02"
  disable_password_authentication = false
  admin_username                  = var.credentials["username"]
  admin_password                  = var.credentials["password"]

  boot_diagnostics {}

  custom_data = base64encode(
    templatefile(
      "data/cloud-init.yml",
      {
        router_id = azurerm_network_interface.hub_sdwan.private_ip_address,
        rs_peer_1 = "10.128.2.4",
        rs_peer_2 = "10.128.2.5"
      }
    )
  )

  tags = var.tags
}

resource "azurerm_lb" "hub_sdwan" {
  name                = "${var.prefix}-${var.org}-lb-sdwan-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  sku = "Standard"

  frontend_ip_configuration {
    name                          = "ipConfig1"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_sdwan.id
  }
}

resource "azurerm_lb_probe" "hub_sdwan" {
  loadbalancer_id = azurerm_lb.hub_sdwan.id
  name            = "probe-ssh"

  protocol            = "Tcp"
  port                = 22
  number_of_probes    = 2
  interval_in_seconds = 5
}

resource "azurerm_lb_backend_address_pool" "hub_sdwan" {
  loadbalancer_id = azurerm_lb.hub_sdwan.id
  name            = "bep-sdwan"
}

resource "azurerm_network_interface_backend_address_pool_association" "hub_sdwan" {
  network_interface_id    = azurerm_network_interface.hub_sdwan.id
  ip_configuration_name   = azurerm_network_interface.hub_sdwan.ip_configuration[0].name
  backend_address_pool_id = azurerm_lb_backend_address_pool.hub_sdwan.id
}

resource "azurerm_lb_rule" "hub_sdwan" {
  name            = "lbr-sdwan"
  loadbalancer_id = azurerm_lb.hub_sdwan.id

  frontend_ip_configuration_name = azurerm_lb.hub_sdwan.frontend_ip_configuration[0].name
  probe_id                       = azurerm_lb_probe.hub_sdwan.id

  frontend_port         = 0
  backend_port          = 0
  protocol              = "All"
  enable_floating_ip    = true
  disable_outbound_snat = true
}

resource "azurerm_monitor_diagnostic_setting" "hub_sdwan" {
  # log_analytics_destination_type = "AzureDiagnostics" # Dedicated
  name               = "${azurerm_lb.hub_sdwan.name}-logdata-01"
  target_resource_id = azurerm_lb.hub_sdwan.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.net_watch_pri.id
  storage_account_id         = azurerm_storage_account.net_watch_pri.id

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
      days    = 7
      enabled = true
    }
  }
}
