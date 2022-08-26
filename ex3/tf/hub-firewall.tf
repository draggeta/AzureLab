resource "azurerm_public_ip" "hub_firewall" {
  name                = "${azurerm_resource_group.hub.name}-azf-01-pi4-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label = "${azurerm_resource_group.hub.name}-azf-01-pi4-01"
}

resource "azurerm_firewall" "hub_firewall" {
  name                = "${azurerm_resource_group.hub.name}-azf-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  firewall_policy_id = azurerm_firewall_policy.hub_firewall.id

  ip_configuration {
    name                 = "ipConfig1"
    subnet_id            = azurerm_subnet.hub_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.hub_firewall.id
  }
}

resource "azurerm_firewall_policy" "hub_firewall" {
  name                = "${azurerm_resource_group.hub.name}-azfp-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  dns {
    proxy_enabled = true
    servers       = ["1.1.1.1", "8.8.8.8"]
  }

  threat_intelligence_mode = "Deny"
}


resource "azurerm_firewall_policy_rule_collection_group" "hub_firewall_default" {
  name               = "rule-collection-grp-default"
  firewall_policy_id = azurerm_firewall_policy.hub_firewall.id
  priority           = 100
  # application_rule_collection {
  #   name     = "app_rule_collection1"
  #   priority = 500
  #   action   = "Deny"
  #   rule {
  #     name = "app_rule_collection1_rule1"
  #     protocols {
  #       type = "Http"
  #       port = 80
  #     }
  #     protocols {
  #       type = "Https"
  #       port = 443
  #     }
  #     source_addresses  = ["10.0.0.1"]
  #     destination_fqdns = ["*.microsoft.com"]
  #   }
  # }

  nat_rule_collection {
    name     = "nat_rule_collection-default"
    priority = 300
    action   = "Dnat"
    rule {
      name                = "Allow-rdp-management"
      protocols           = ["TCP", "UDP"]
      source_addresses    = [data.http.ip.response_body]
      destination_address = azurerm_public_ip.hub_firewall.ip_address
      destination_ports   = ["3389"]
      translated_address  = azurerm_network_interface.hub_management.private_ip_address
      translated_port     = "3389"
    }
  }

  network_rule_collection {
    name     = "network-rule-collection-default"
    priority = 500
    action   = "Allow"
    rule {
      name                  = "Allow-internet"
      protocols             = ["TCP", "UDP", "ICMP", "Any"]
      source_addresses      = ["10.128.0.0/14"]
      destination_addresses = ["0.0.0.0/0"]
      destination_ports     = ["*"]
    }
    rule {
      name                  = "Allow-spoke-to-spoke"
      protocols             = ["TCP", "UDP", "ICMP", "Any"]
      source_ip_groups      = [azurerm_ip_group.spoke_a_web.id, azurerm_ip_group.spoke_b_web.id]
      destination_ip_groups = [azurerm_ip_group.spoke_a_web.id, azurerm_ip_group.spoke_b_web.id]
      destination_ports     = ["*"]
      # source_addresses      = ["10.128.0.0/14"]
      # destination_addresses = ["10.128.0.0/14"]
    }
  }
}

resource "azurerm_monitor_diagnostic_setting" "hub_firewall" {
  log_analytics_destination_type = "AzureDiagnostics" # Dedicated
  name                           = "${azurerm_firewall.hub_firewall.name}-logdata-01"
  target_resource_id             = azurerm_firewall.hub_firewall.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.net_watch_pri.id
  storage_account_id         = azurerm_storage_account.net_watch_pri.id

  log {
    category = "AzureFirewallApplicationRule"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AZFWApplicationRule"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AZFWApplicationRuleAggregation"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = true
    }
  }

  log {
    category = "AzureFirewallNetworkRule"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AZFWNetworkRule"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AZFWNetworkRuleAggregation"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = true
    }
  }

  log {
    category = "AZFWNatRule"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AZFWNatRuleAggregation"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = true
    }
  }

  log {
    category = "AZFWIdpsSignature"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = true
    }
  }
  log {
    category = "AZFWThreatIntel"
    enabled  = true

    retention_policy {
      days    = 0
      enabled = true
    }
  }

  log {
    category = "AZFWFqdnResolveFailure"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AZFWDnsQuery"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }
  log {
    category = "AzureFirewallDnsProxy"
    enabled  = true

    retention_policy {
      days    = 7
      enabled = true
    }
  }

  metric {
    category = "AllMetrics"
    enabled  = false

    retention_policy {
      days    = 0
      enabled = false
    }
  }
}
