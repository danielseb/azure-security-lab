terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Backend configuration - uncomment after running setup-backend.sh
  # backend "azurerm" {
  #   resource_group_name  = "terraform-state-rg"
  #   storage_account_name = "tfstate<random>"
  #   container_name       = "tfstate"
  #   key                  = "security-lab.tfstate"
  # }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Random string for unique naming
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "lab" {
  name     = "${var.resource_prefix}-rg"
  location = var.location

  tags = {
    Environment = "Lab"
    Project     = "SecurityLab"
    ManagedBy   = "Terraform"
  }
}

# Public IP for Attacker VM
resource "azurerm_public_ip" "attacker" {
  name                = "${var.resource_prefix}-attacker-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                = "Standard"

  tags = {
    Environment = "Lab"
    Purpose     = "Attacker-VM-Access"
  }
}

# Public IP for NAT Gateway (for outbound internet from web/SIEM)
resource "azurerm_public_ip" "nat" {
  name                = "${var.resource_prefix}-nat-pip"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  allocation_method   = "Static"
  sku                = "Standard"

  tags = {
    Environment = "Lab"
    Purpose     = "NAT-Gateway"
  }
}

# NAT Gateway for outbound internet access
resource "azurerm_nat_gateway" "lab" {
  name                = "${var.resource_prefix}-nat-gateway"
  location            = azurerm_resource_group.lab.location
  resource_group_name = azurerm_resource_group.lab.name
  sku_name           = "Standard"

  tags = {
    Environment = "Lab"
  }
}

# Associate NAT Gateway with Public IP
resource "azurerm_nat_gateway_public_ip_association" "lab" {
  nat_gateway_id       = azurerm_nat_gateway.lab.id
  public_ip_address_id = azurerm_public_ip.nat.id
}