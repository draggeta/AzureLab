resource "azurerm_resource_group" "op" {
  name     = "ams-tst-${var.org}-op-01"
  location = var.primary_location
}

resource "azurerm_virtual_network" "op" {
  name                = "${azurerm_resource_group.op.name}-vnet-01"
  location            = azurerm_resource_group.op.location
  resource_group_name = azurerm_resource_group.op.name
  address_space       = ["10.10.0.0/24"]

  tags = var.tags
}

resource "azurerm_subnet" "op_fw" {
  name                 = "fw"
  resource_group_name  = azurerm_resource_group.op.name
  virtual_network_name = azurerm_virtual_network.op.name
  address_prefixes     = ["10.10.0.0/24"]
}

resource "azurerm_network_security_group" "op_fw" {
  name                = "${azurerm_virtual_network.op.name}-fw-nsg-01"
  location            = azurerm_resource_group.op.location
  resource_group_name = azurerm_resource_group.op.name

  security_rule {
    name                       = "AllowSshInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 22
    source_address_prefix      = data.http.ip.response_body
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowIPsecInbound"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_ranges    = [500, 4500]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }
  security_rule {
    name                       = "AllowHttpInbound"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = 80
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "op_fw_to_op_fw" {
  subnet_id                 = azurerm_subnet.op_fw.id
  network_security_group_id = azurerm_network_security_group.op_fw.id
}

resource "azurerm_public_ip" "op_fw" {
  name                = "fw01-nic-01-pi4-01"
  location            = azurerm_resource_group.op.location
  resource_group_name = azurerm_resource_group.op.name
  allocation_method   = "Static"
  sku                 = "Standard"

  domain_name_label = "${var.prefix}-${var.org}-fw01"
}

resource "azurerm_network_interface" "op_fw" {
  name                = "fw01-nic-01"
  location            = azurerm_resource_group.op.location
  resource_group_name = azurerm_resource_group.op.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.op_fw.id
    private_ip_address_allocation = "Dynamic"

    public_ip_address_id = azurerm_public_ip.op_fw.id
  }
  enable_ip_forwarding = true
}

resource "azurerm_linux_virtual_machine" "op_fw" {
  name                  = "fw01"
  location              = azurerm_resource_group.op.location
  resource_group_name   = azurerm_resource_group.op.name
  network_interface_ids = [azurerm_network_interface.op_fw.id]
  size                  = "Standard_B1s"

  zone = 1

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name    = "fw01-os-disk"
    caching = "ReadWrite"
    # create_option        = "FromImage"
    storage_account_type = "StandardSSD_LRS"
  }

  computer_name                   = "fw01"
  disable_password_authentication = false
  admin_username                  = var.credentials["username"]
  admin_password                  = var.credentials["password"]

  boot_diagnostics {}

  custom_data = base64encode(
    templatefile(
      "data/cloud-init.vpn.yml",
      {
        vgw_peer_1     = azurerm_public_ip.hub_vpngw_1.ip_address,
        vgw_bgp_peer_1 = azurerm_virtual_network_gateway.hub_vpngw.bgp_settings[0].peering_addresses[0].default_addresses[0],
        vgw_peer_2     = azurerm_public_ip.hub_vpngw_2.ip_address,
        vgw_bgp_peer_2 = azurerm_virtual_network_gateway.hub_vpngw.bgp_settings[0].peering_addresses[1].default_addresses[0]
      }
    )
  )

  tags = var.tags
}
