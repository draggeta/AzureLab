resource "azurerm_public_ip" "hub_vpngw_1" {
  name                = "${azurerm_resource_group.hub.name}-vgw-01-pi4-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
resource "azurerm_public_ip" "hub_vpngw_2" {
  name                = "${azurerm_resource_group.hub.name}-vgw-01-pi4-02"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}
# IP for client VPN
resource "azurerm_public_ip" "hub_vpngw_3" {
  name                = "${azurerm_resource_group.hub.name}-vgw-01-pi4-03"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_virtual_network_gateway" "hub_vpngw" {
  name                = "${azurerm_resource_group.hub.name}-vgw-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  type     = "Vpn"
  vpn_type = "RouteBased"

  active_active = true
  enable_bgp    = true
  sku           = "VpnGw1"
  # generation    = "Generation2"

  custom_route {
    address_prefixes = []
  }

  ip_configuration {
    name                          = "vnetGatewayConfig1"
    public_ip_address_id          = azurerm_public_ip.hub_vpngw_1.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway_subnet.id
  }
  ip_configuration {
    name                          = "vnetGatewayConfig2"
    public_ip_address_id          = azurerm_public_ip.hub_vpngw_2.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway_subnet.id
  }
  # Client VPN
  ip_configuration {
    name                          = "vnetGatewayConfig3"
    public_ip_address_id          = azurerm_public_ip.hub_vpngw_3.id
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.hub_gateway_subnet.id
  }

  bgp_settings {
    asn = 65515
    peering_addresses {
      ip_configuration_name = "vnetGatewayConfig1"
    }
    peering_addresses {
      ip_configuration_name = "vnetGatewayConfig2"
    }
  }

  vpn_client_configuration {
    address_space = ["10.96.0.0/24"]

    vpn_client_protocols = ["OpenVPN"]
    vpn_auth_types       = ["AAD"]

    aad_tenant   = "https://login.microsoftonline.com/${data.azurerm_client_config.current.tenant_id}/"
    aad_audience = "41b23e61-6c1e-4545-b367-cd054e0ed4b4"
    aad_issuer   = "https://sts.windows.net/${data.azurerm_client_config.current.tenant_id}/"
  }
}

resource "azurerm_local_network_gateway" "hub_vpngw_to_op_fw" {
  name                = "${azurerm_resource_group.hub.name}-lng-on-prem-fw-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name
  gateway_address     = azurerm_public_ip.op_fw.ip_address

  bgp_settings {
    asn                 = 65003
    bgp_peering_address = "10.64.255.255"
  }
}

resource "azurerm_virtual_network_gateway_connection" "hub_vpngw_to_op_fw" {
  name                = "${azurerm_resource_group.hub.name}-vgw-01-to-lng-on-prem-fw-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  type                       = "IPsec"
  virtual_network_gateway_id = azurerm_virtual_network_gateway.hub_vpngw.id
  local_network_gateway_id   = azurerm_local_network_gateway.hub_vpngw_to_op_fw.id
  connection_protocol        = "IKEv2"

  dpd_timeout_seconds = 45

  ipsec_policy {
    ike_encryption = "GCMAES128"
    ike_integrity  = "SHA256"
    dh_group       = "ECP384"

    ipsec_encryption = "GCMAES128"
    ipsec_integrity  = "GCMAES128"
    pfs_group        = "ECP384"

    sa_datasize = 1024000000
    sa_lifetime = 3600
  }

  enable_bgp = true

  shared_key = "DitIsEENV4ilugP0sSwerd!"
}
