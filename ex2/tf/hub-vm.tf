# resource "azurerm_public_ip" "hub_management" {
#   name                = "mgt01-nic-01-pi4-01"
#   resource_group_name = azurerm_resource_group.hub.name
#   location            = azurerm_resource_group.hub.location
#   allocation_method   = "Dynamic"
#   sku                 = "Basic"
#   domain_name_label   = "${var.prefix}-${var.org}-mgt01"

#   tags = var.tags
# }

resource "azurerm_network_interface" "hub_management" {
  name                = "mgt01-nic-01"
  location            = azurerm_resource_group.hub.location
  resource_group_name = azurerm_resource_group.hub.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.hub_management.id
    private_ip_address_allocation = "Dynamic"
    # public_ip_address_id          = azurerm_public_ip.hub_management.id
  }
}

resource "azurerm_windows_virtual_machine" "hub_management" {
  name                  = "mgt01"
  location              = azurerm_resource_group.hub.location
  resource_group_name   = azurerm_resource_group.hub.name
  network_interface_ids = [azurerm_network_interface.hub_management.id]
  size                  = "Standard_B2ms"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  os_disk {
    name    = "mgt01-os-disk"
    caching = "ReadWrite"
    # create_option        = "FromImage"
    storage_account_type = "StandardSSD_LRS"
  }

  computer_name  = "mgt01"
  admin_username = var.credentials["username"]
  admin_password = var.credentials["password"]

  boot_diagnostics {}

  tags = var.tags
}
