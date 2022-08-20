# resource "azurerm_resource_group" "net_watch" {
#   name     = "NetworkWatcherRG"
#   location = var.primary_location
# }
data "azurerm_resource_group" "net_watch" {
  name = "NetworkWatcherRG"
}

# Log collection components
resource "azurerm_storage_account" "net_watch_pri" {
  name = "${replace(var.prefix, "-", "")}${var.org}logdata01"
  # resource_group_name = azurerm_resource_group.net_watch.name
  # location            = azurerm_resource_group.net_watch.location
  resource_group_name = data.azurerm_resource_group.net_watch.name
  location            = var.primary_location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

resource "azurerm_log_analytics_workspace" "net_watch_pri" {
  name = "${var.prefix}-${var.org}-log-data-01"
  # location            = azurerm_resource_group.net_watch.location
  # resource_group_name = azurerm_resource_group.net_watch.name
  location            = data.azurerm_resource_group.net_watch.location
  resource_group_name = data.azurerm_resource_group.net_watch.name
  retention_in_days   = 30
  daily_quota_gb      = 10
}

# The Network Watcher Instance & network log flow
# There can only be one Network Watcher per subscription and region

# resource "azurerm_network_watcher" "net_watch_pri" {
#   name = "NetworkWatcher_${replace(lower(var.primary_location), " ", "")}"
#   # location            = azurerm_resource_group.net_watch.location
#   # resource_group_name = azurerm_resource_group.net_watch.name
#   location            = data.azurerm_resource_group.net_watch.location
#   resource_group_name = data.azurerm_resource_group.net_watch.name
# }

data "azurerm_network_watcher" "net_watch_pri" {
  name                = "NetworkWatcher_${replace(lower(var.primary_location), " ", "")}"
  resource_group_name = data.azurerm_resource_group.net_watch.name
}

resource "azurerm_network_watcher_flow_log" "net_watch_pri_hub" {
  name                 = azurerm_network_security_group.hub_management.name
  network_watcher_name = data.azurerm_network_watcher.net_watch_pri.name
  location             = data.azurerm_network_watcher.net_watch_pri.location
  resource_group_name  = data.azurerm_network_watcher.net_watch_pri.resource_group_name

  network_security_group_id = azurerm_network_security_group.hub_management.id
  storage_account_id        = azurerm_storage_account.net_watch_pri.id
  enabled                   = true

  version = 2

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.net_watch_pri.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.net_watch_pri.location
    workspace_resource_id = azurerm_log_analytics_workspace.net_watch_pri.id
    interval_in_minutes   = 10
  }
}

resource "azurerm_network_watcher_flow_log" "net_watch_pri_spoke_a" {
  name                 = azurerm_network_security_group.spoke_a_web.name
  network_watcher_name = data.azurerm_network_watcher.net_watch_pri.name
  location             = data.azurerm_network_watcher.net_watch_pri.location
  resource_group_name  = data.azurerm_network_watcher.net_watch_pri.resource_group_name

  network_security_group_id = azurerm_network_security_group.spoke_a_web.id
  storage_account_id        = azurerm_storage_account.net_watch_pri.id
  enabled                   = true

  version = 2

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.net_watch_pri.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.net_watch_pri.location
    workspace_resource_id = azurerm_log_analytics_workspace.net_watch_pri.id
    interval_in_minutes   = 10
  }
}




# Log collection components
resource "azurerm_storage_account" "net_watch_sec" {
  name = "${replace(var.secondary_prefix, "-", "")}${var.org}logdata01"
  # resource_group_name = azurerm_resource_group.net_watch.name
  # location            = azurerm_resource_group.net_watch.location
  resource_group_name = data.azurerm_resource_group.net_watch.name
  location            = var.secondary_location

  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
}

# resource "azurerm_network_watcher" "net_watch_sec" {
#   name = "NetworkWatcher_${replace(lower(var.secondary_location), " ", "")}"
#   # location            = azurerm_resource_group.net_watch.location
#   # resource_group_name = azurerm_resource_group.net_watch.name
#   location            = data.azurerm_resource_group.net_watch.location
#   resource_group_name = data.azurerm_resource_group.net_watch.name
# }

data "azurerm_network_watcher" "net_watch_sec" {
  name                = "NetworkWatcher_${replace(lower(var.secondary_location), " ", "")}"
  resource_group_name = data.azurerm_resource_group.net_watch.name
}

resource "azurerm_network_watcher_flow_log" "net_watch_sec_spoke_b" {
  name                 = azurerm_network_security_group.spoke_b_web.name
  network_watcher_name = data.azurerm_network_watcher.net_watch_sec.name
  location             = data.azurerm_network_watcher.net_watch_sec.location
  resource_group_name  = data.azurerm_network_watcher.net_watch_sec.resource_group_name

  network_security_group_id = azurerm_network_security_group.spoke_b_web.id
  storage_account_id        = azurerm_storage_account.net_watch_sec.id
  enabled                   = true

  version = 2

  retention_policy {
    enabled = true
    days    = 90
  }

  traffic_analytics {
    enabled               = true
    workspace_id          = azurerm_log_analytics_workspace.net_watch_pri.workspace_id
    workspace_region      = azurerm_log_analytics_workspace.net_watch_pri.location
    workspace_resource_id = azurerm_log_analytics_workspace.net_watch_pri.id
    interval_in_minutes   = 10
  }
}
