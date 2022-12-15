resource "azurerm_subnet" "spoke_b_fa_pe" {
  name                 = "privateEndpoint"
  resource_group_name  = azurerm_resource_group.spoke_b.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.130.5.0/24"]

  private_endpoint_network_policies_enabled = true
}

resource "azurerm_network_security_group" "spoke_b_fa_pe" {
  name                = "${azurerm_virtual_network.spoke_b.name}-private-endpoint-nsg-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name

  security_rule {
    name                       = "AllowHttpMgmtServer"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = [80]
    source_address_prefixes    = [azurerm_subnet.hub_management.address_prefixes[0]]
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "DenyHttpOtherInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = [80]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "spoke_b_fa_pe_to_spoke_b_fa_pe" {
  subnet_id                 = azurerm_subnet.spoke_b_fa_pe.id
  network_security_group_id = azurerm_network_security_group.spoke_b_fa_pe.id
}

resource "azurerm_storage_account" "spoke_b_fa" {
  name                     = substr(replace(join("", [var.prefix, var.org, "bfap", random_id.unique.hex]), "/[-_\\s\\+]/", ""), 0, 24)
  location                 = azurerm_resource_group.spoke_b.location
  resource_group_name      = azurerm_resource_group.spoke_b.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "spoke_b_fa" {
  name                = "${azurerm_resource_group.spoke_b.name}-asp-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "spoke_b_fa" {
  name                = "${azurerm_resource_group.spoke_b.name}-fap-01-${random_id.unique.hex}"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name

  storage_account_name       = azurerm_storage_account.spoke_b_fa.name
  storage_account_access_key = azurerm_storage_account.spoke_b_fa.primary_access_key
  service_plan_id            = azurerm_service_plan.spoke_b_fa.id

  functions_extension_version = "~4"

  site_config {
    application_stack {
      python_version = "3.9"
    }
    ip_restriction {
      name       = "Internet access"
      action     = "Allow"
      ip_address = "0.0.0.0/0"
    }
  }
}

resource "azurerm_app_service_source_control" "spoke_b_fa" {
  app_id                 = azurerm_linux_function_app.spoke_b_fa.id
  repo_url               = "https://github.com/draggeta/AzureLabFunction"
  branch                 = "master"
  use_manual_integration = true
}

resource "azurerm_private_endpoint" "spoke_b_fa_pe" {
  name                = "${azurerm_linux_function_app.spoke_b_fa.name}-pe-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name
  subnet_id           = azurerm_subnet.spoke_b_fa_pe.id


  private_service_connection {
    name                           = "${azurerm_linux_function_app.spoke_b_fa.name}-pe-01"
    private_connection_resource_id = azurerm_linux_function_app.spoke_b_fa.id
    subresource_names              = ["sites"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "spoke-b-fa"
    private_dns_zone_ids = [azurerm_private_dns_zone.priv_az_web.id]
  }
}
