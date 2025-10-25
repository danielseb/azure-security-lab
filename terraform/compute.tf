# Network Interface for Attacker VM
resource "azurerm_network_interface" "attacker" {
  name                = "${var.resource_prefix}-attacker-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.attacker.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.attacker.id
  }

  tags = {
    Environment = "Lab"
  }
}

# Network Interface for Web Server
resource "azurerm_network_interface" "webserver" {
  name                = "${var.resource_prefix}-webserver-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.webserver.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.2.4"
  }

  tags = {
    Environment = "Lab"
  }
}

# Network Interface for SIEM
resource "azurerm_network_interface" "siem" {
  name                = "${var.resource_prefix}-siem-nic"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.siem.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.3.4"
  }

  tags = {
    Environment = "Lab"
  }
}

# Attacker VM
resource "azurerm_linux_virtual_machine" "attacker" {
  name                  = "${var.resource_prefix}-attacker-vm"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  network_interface_ids = [azurerm_network_interface.attacker.id]
  size                  = "Standard_B2s"

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/cloud-init/attacker-init.sh"))

  tags = {
    Environment = "Lab"
    Role        = "Attacker"
  }
}

# Web Server VM
resource "azurerm_linux_virtual_machine" "webserver" {
  name                  = "${var.resource_prefix}-webserver-vm"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  network_interface_ids = [azurerm_network_interface.webserver.id]
  size                  = "Standard_B2s"

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(templatefile("${path.module}/cloud-init/webserver-init.sh", {
    siem_ip = "10.0.3.4"
  }))

  tags = {
    Environment = "Lab"
    Role        = "WebServer"
  }
}

# SIEM VM
resource "azurerm_linux_virtual_machine" "siem" {
  name                  = "${var.resource_prefix}-siem-vm"
  location              = azurerm_resource_group.lab.location
  resource_group_name   = azurerm_resource_group.lab.name
  network_interface_ids = [azurerm_network_interface.siem.id]
  size                  = "Standard_D2s_v3"

  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 50
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  custom_data = base64encode(file("${path.module}/cloud-init/siem-init.sh"))

  tags = {
    Environment = "Lab"
    Role        = "SIEM"
  }
}