resource "azurerm_subnet" "spoke_a_fa_vi" {
  name                 = "vnetIntegration"
  resource_group_name  = azurerm_resource_group.spoke_a.name
  virtual_network_name = azurerm_virtual_network.spoke_a.name
  address_prefixes     = ["10.129.5.0/24"]

  delegation {
    name = "Microsoft.Web.serverFarms"
    service_delegation {
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/action",
      ]
      name = "Microsoft.Web/serverFarms"
    }
  }
}

resource "azurerm_storage_account" "spoke_a_fa" {
  name                     = substr(replace(join("", [var.prefix, var.org, "afap", random_id.unique.hex]), "/[-_\\s\\+]/", ""), 0, 24)
  resource_group_name      = azurerm_resource_group.spoke_a.name
  location                 = azurerm_resource_group.spoke_a.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "spoke_a_fa" {
  name                = "${azurerm_resource_group.spoke_a.name}-asp-01"
  resource_group_name = azurerm_resource_group.spoke_a.name
  location            = azurerm_resource_group.spoke_a.location
  os_type             = "Linux"
  sku_name            = "B1"
}

resource "azurerm_linux_function_app" "spoke_a_fa" {
  name                = "${azurerm_resource_group.spoke_a.name}-fap-01-${random_id.unique.hex}"
  resource_group_name = azurerm_resource_group.spoke_a.name
  location            = azurerm_resource_group.spoke_a.location

  storage_account_name       = azurerm_storage_account.spoke_a_fa.name
  storage_account_access_key = azurerm_storage_account.spoke_a_fa.primary_access_key
  service_plan_id            = azurerm_service_plan.spoke_a_fa.id

  functions_extension_version = "~4"

  virtual_network_subnet_id = azurerm_subnet.spoke_a_fa_vi.id

  site_config {
    application_stack {
      python_version = "3.9"
    }
    vnet_route_all_enabled = true
  }
}

resource "azurerm_app_service_source_control" "spoke_a_fa" {
  app_id                 = azurerm_linux_function_app.spoke_a_fa.id
  repo_url               = "https://github.com/draggeta/AzureLabFunction"
  branch                 = "master"
  use_manual_integration = true
}
