# Virtual Network
resource "azurerm_virtual_network" "lab" {
  name                = "${var.resource_prefix}-vnet"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  address_space       = ["10.0.0.0/16"]

  tags = {
    Environment = "Lab"
  }
}

# Subnet for Attacker VM
resource "azurerm_subnet" "attacker" {
  name                 = "attacker-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Subnet for Web Server
resource "azurerm_subnet" "webserver" {
  name                 = "webserver-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Subnet for SIEM
resource "azurerm_subnet" "siem" {
  name                 = "siem-subnet"
  resource_group_name  = azurerm_resource_group.lab.name
  virtual_network_name = azurerm_virtual_network.lab.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Associate NAT Gateway with Web Server subnet
resource "azurerm_subnet_nat_gateway_association" "webserver" {
  subnet_id      = azurerm_subnet.webserver.id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

# Associate NAT Gateway with SIEM subnet
resource "azurerm_subnet_nat_gateway_association" "siem" {
  subnet_id      = azurerm_subnet.siem.id
  nat_gateway_id = azurerm_nat_gateway.lab.id
}

# Network Security Group for Attacker VM
resource "azurerm_network_security_group" "attacker" {
  name                = "${var.resource_prefix}-attacker-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # Allow SSH from your IP only
  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.allowed_ssh_ip
    destination_address_prefix = "*"
  }

  # Allow outbound to web server subnet
  security_rule {
    name                       = "AllowWebServer"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.2.0/24"
  }

  # Allow outbound to SIEM subnet
  security_rule {
    name                       = "AllowSIEM"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.3.0/24"
  }

  # Allow outbound internet
  security_rule {
    name                       = "AllowInternet"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = {
    Environment = "Lab"
  }
}

# Network Security Group for Web Server
resource "azurerm_network_security_group" "webserver" {
  name                = "${var.resource_prefix}-webserver-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # Allow SSH from attacker subnet
  security_rule {
    name                       = "AllowSSHFromAttacker"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Allow HTTP from attacker subnet
  security_rule {
    name                       = "AllowHTTPFromAttacker"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3000"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Allow communication to SIEM (for log shipping)
  security_rule {
    name                       = "AllowSIEM"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = "*"
    destination_address_prefix = "10.0.3.0/24"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Lab"
  }
}

# Network Security Group for SIEM
resource "azurerm_network_security_group" "siem" {
  name                = "${var.resource_prefix}-siem-nsg"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name

  # Allow SSH from attacker subnet
  security_rule {
    name                       = "AllowSSHFromAttacker"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Allow Elasticsearch from web server
  security_rule {
    name                       = "AllowElasticsearch"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "9200"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # Allow Kibana from attacker subnet
  security_rule {
    name                       = "AllowKibanaFromAttacker"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "5601"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }

  # Deny all other inbound traffic
  security_rule {
    name                       = "DenyAllInbound"
    priority                   = 4096
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Lab"
  }
}

# Associate NSGs with Subnets
resource "azurerm_subnet_network_security_group_association" "attacker" {
  subnet_id                 = azurerm_subnet.attacker.id
  network_security_group_id = azurerm_network_security_group.attacker.id
}

resource "azurerm_subnet_network_security_group_association" "webserver" {
  subnet_id                 = azurerm_subnet.webserver.id
  network_security_group_id = azurerm_network_security_group.webserver.id
}

resource "azurerm_subnet_network_security_group_association" "siem" {
  subnet_id                 = azurerm_subnet.siem.id
  network_security_group_id = azurerm_network_security_group.siem.id
}