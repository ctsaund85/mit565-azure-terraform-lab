###############################################################################
# Windows Server Module – Main
# MIT 565 Azure Lab
#
# Concepts demonstrated:
#   - Static IP addressing (critical for DNS servers)
#   - DNS server role installation
#   - NIC-level DNS configuration
#   - ARP/MAC behavior (each NIC gets a virtual MAC in Azure)
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
    private_ip_address_allocation = var.private_ip_address != null ? "Static" : "Dynamic"
    private_ip_address            = var.private_ip_address
  }
}

resource "azurerm_windows_virtual_machine" "server" {
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
  virtual_machine_id         = azurerm_windows_virtual_machine.server.id
  publisher                  = "Microsoft.Compute"
  type                       = "BGInfo"
  type_handler_version       = "2.2"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

# Install DNS Server role via Custom Script Extension
resource "azurerm_virtual_machine_extension" "install_dns" {
  count                = var.install_dns ? 1 : 0
  name                 = "install-dns-${var.vm_name}"
  virtual_machine_id   = azurerm_windows_virtual_machine.server.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode({
    commandToExecute = "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name DNS -IncludeManagementTools; Add-DnsServerPrimaryZone -Name 'mit565.local' -ZoneFile 'mit565.local.dns'; Add-DnsServerResourceRecordA -ZoneName 'mit565.local' -Name 'dns-server' -IPv4Address '10.10.2.10'; Add-DnsServerResourceRecordA -ZoneName 'mit565.local' -Name 'web-server' -IPv4Address '10.10.2.20'; Add-DnsServerResourceRecordA -ZoneName 'mit565.local' -Name 'branch1-client' -IPv4Address '10.10.0.10'; Add-DnsServerResourceRecordA -ZoneName 'mit565.local' -Name 'branch2-client' -IPv4Address '10.20.0.10'; Add-DnsServerForwarder -IPAddress 168.63.129.16; $ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('C:\\Users\\Public\\Desktop\\DNS Manager.lnk'); $s.TargetPath = 'dnsmgmt.msc'; $s.Save(); @('[InternetShortcut]','URL=https://www.ipchicken.com') | Set-Content 'C:\\Users\\Public\\Desktop\\IP Chicken.url'\""
  })
}

# Install IIS Web Server role and deploy website
resource "azurerm_virtual_machine_extension" "install_iis" {
  count                = var.install_iis ? 1 : 0
  name                 = "install-iis-${var.vm_name}"
  virtual_machine_id   = azurerm_windows_virtual_machine.server.id
  publisher            = "Microsoft.Compute"
  type                 = "CustomScriptExtension"
  type_handler_version = "1.10"

  settings = jsonencode(merge(
    {
      commandToExecute = var.iis_content_url != null ? "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; Copy-Item -Path './index.html' -Destination 'C:\\inetpub\\wwwroot\\index.html' -Force; $ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('C:\\Users\\Public\\Desktop\\IIS Manager.lnk'); $s.TargetPath = 'C:\\Windows\\System32\\inetsrv\\InetMgr.exe'; $s.Save(); @('[InternetShortcut]','URL=https://www.ipchicken.com') | Set-Content 'C:\\Users\\Public\\Desktop\\IP Chicken.url'\"" : "powershell -ExecutionPolicy Unrestricted -Command \"Install-WindowsFeature -Name Web-Server -IncludeManagementTools; $ws = New-Object -ComObject WScript.Shell; $s = $ws.CreateShortcut('C:\\Users\\Public\\Desktop\\IIS Manager.lnk'); $s.TargetPath = 'C:\\Windows\\System32\\inetsrv\\InetMgr.exe'; $s.Save(); @('[InternetShortcut]','URL=https://www.ipchicken.com') | Set-Content 'C:\\Users\\Public\\Desktop\\IP Chicken.url'\""
    },
    var.iis_content_url != null ? { fileUris = [var.iis_content_url] } : {}
  ))
}