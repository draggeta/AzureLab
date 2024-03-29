resource "azurerm_subnet" "spoke_b_web" {
  name                 = "web"
  resource_group_name  = azurerm_resource_group.spoke_b.name
  virtual_network_name = azurerm_virtual_network.spoke_b.name
  address_prefixes     = ["10.130.5.0/24"]
}

resource "azurerm_network_interface" "spoke_b_web" {
  name                = "web02-nic-01"
  location            = azurerm_resource_group.spoke_b.location
  resource_group_name = azurerm_resource_group.spoke_b.name

  ip_configuration {
    name                          = "ipConfig1"
    subnet_id                     = azurerm_subnet.spoke_b_web.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_linux_virtual_machine" "spoke_b_web" {
  name                  = "web02"
  location              = azurerm_resource_group.spoke_b.location
  resource_group_name   = azurerm_resource_group.spoke_b.name
  network_interface_ids = [azurerm_network_interface.spoke_b_web.id]
  size                  = "Standard_B1s"

  zone = 1

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  os_disk {
    name    = "web02-os-disk"
    caching = "ReadWrite"
    # create_option        = "FromImage"
    storage_account_type = "StandardSSD_LRS"
  }

  computer_name                   = "web02"
  disable_password_authentication = false
  admin_username                  = var.credentials["username"]
  admin_password                  = var.credentials["password"]

  boot_diagnostics {}

  depends_on = [
    azurerm_firewall.hub_firewall,
    azurerm_firewall_policy_rule_collection_group.hub_firewall_default,
    azurerm_virtual_network_peering.hub_to_spoke_b,
    azurerm_virtual_network_peering.spoke_b_to_hub
  ]

  custom_data = base64encode(<<EOF
#!/bin/bash

# license: https://raw.githubusercontent.com/Azure-Samples/compute-automation-configurations/master/automate_nginx.sh
apt-get update -y && apt-get upgrade -y
apt-get install -y nginx jq
LOC=$(curl -s -H Metadata:true --noproxy "*" "http://169.254.169.254/metadata/instance?api-version=2021-02-01" | jq '.compute.location')
echo "{\"service\": \"Finance API\", \"location\": $LOC, \"server\": \"$HOSTNAME\"}" | sudo tee /var/www/html/index.html
sudo mkdir -p /var/www/html/health/
echo "{\"health\": \"ok\"}" | sudo tee /var/www/html/health/index.html
EOF
  )

  tags = var.tags
}
