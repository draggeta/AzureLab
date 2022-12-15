resource "azurerm_resource_group" "fd" {
  name     = "${var.prefix}-${var.org}-front-door-01"
  location = var.primary_location
}

resource "azurerm_cdn_frontdoor_profile" "fd" {
  name                = "${var.prefix}-${var.org}-fd-01-${random_id.unique.hex}"
  resource_group_name = azurerm_resource_group.fd.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_endpoint" "fd" {
  name                     = "default"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  tags = var.tags
}

resource "azurerm_cdn_frontdoor_origin_group" "fd_az" {
  name                     = "azure"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  load_balancing {}
}

resource "azurerm_cdn_frontdoor_origin" "fd_az_a" {
  name                          = "spoke_a"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_az.id
  enabled                       = true

  certificate_name_check_enabled = false

  host_name          = azurerm_linux_function_app.spoke_a_fa.default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_linux_function_app.spoke_a_fa.default_hostname
  priority           = 1
  weight             = 1
}

resource "azurerm_cdn_frontdoor_origin" "fd_az_b" {
  name                          = "spoke-b"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_az.id
  enabled                       = true

  certificate_name_check_enabled = true

  host_name          = azurerm_linux_function_app.spoke_b_fa.default_hostname
  http_port          = 80
  https_port         = 443
  origin_host_header = azurerm_linux_function_app.spoke_b_fa.default_hostname
  priority           = 1
  weight             = 1
}

resource "azurerm_cdn_frontdoor_origin_group" "fd_op" {
  name                     = "on-prem"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id

  load_balancing {}
}

resource "azurerm_cdn_frontdoor_origin" "fd_op_01" {
  name                          = "on-prem-fw-01"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_az.id
  enabled                       = true

  certificate_name_check_enabled = false

  host_name          = azurerm_public_ip.op_fw.domain_name_label
  # http_port          = 80
  # https_port         = 443
  # origin_host_header = azurerm_linux_function_app.spoke_a_fa.default_hostname
  # priority           = 1
  # weight             = 1
}

resource "azurerm_cdn_frontdoor_route" "fd_default" {
  name                          = "default"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.fd.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.fd_az.id
  # cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.fd.id]
  cdn_frontdoor_rule_set_ids    = [azurerm_cdn_frontdoor_rule_set.fd.id]
  enabled                       = true

  forwarding_protocol    = "HttpsOnly"
  https_redirect_enabled = true
  patterns_to_match      = ["/*"]
  supported_protocols    = ["Http", "Https"]

  # cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.contoso.id, azurerm_cdn_frontdoor_custom_domain.fabrikam.id]
  link_to_default_domain          = true

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    # query_strings                 = ["account", "settings"]
    compression_enabled           = true
    content_types_to_compress     = ["text/html", "text/javascript", "text/xml", "application/json"]
  }
}

resource "azurerm_cdn_frontdoor_rule_set" "fd_default" {
  name                     = "fdruleset"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.fd.id
}
