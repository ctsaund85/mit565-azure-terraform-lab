###############################################################################
# Windows Client Module – Main
# MIT 565 Azure Lab
#
# Concepts demonstrated:
#   - Dynamic IP addressing (DHCP equivalent in Azure)
#   - DNS client configuration (pointing to custom DNS server)
#   - ARP resolution, default gateway behavior
#   - Each VM gets a NIC with a virtual MAC address
###############################################################################

resource "azurerm_network_interface" "nic" {
  name                = "nic-${var.vm_name}"
  location            = var.region
  resource_group_name = var.resource_group_name
  dns_servers         = length(var.dns_servers) > 0 ? var.dns_servers : null
  tags                = var.tags

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "client" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.region
  size                = var.vm_size
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  tags                = var.tags

  # Spot VM pricing (saves ~60-90% for lab/dev workloads)
  priority        = var.use_spot ? "Spot" : "Regular"
  eviction_policy = var.use_spot ? "Deallocate" : null
  max_bid_price   = var.use_spot ? -1 : null

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# BGInfo – displays system info (IP, hostname, OS) on the desktop wallpaper
resource "azurerm_virtual_machine_extension" "bginfo" {
  name                       = "bginfo-${var.vm_name}"
  virtual_machine_id         = azurerm_windows_virtual_machine.client.id
  publisher                  = "Microsoft.Compute"
  type                       = "BGInfo"
  type_handler_version       = "2.2"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Desktop shortcut – IP Chicken (verifies NAT Gateway public IP)
resource "azurerm_virtual_machine_extension" "shortcuts" {
  name                 = "shortcuts-${var.vm_name}"
  virtual_machine_id   = azurerm_windows_virtual_machine.client.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"@('[InternetShortcut]','URL=https://www.ipchicken.com') | Set-Content 'C:\\Users\\Public\\Desktop\\IP Chicken.url'\""
  })
}