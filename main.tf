variable "subscription_id" { type = string }
variable "client_id" { type = string }
variable "client_secret" { type = string }
variable "tenant_id" { type = string }


terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=4.1.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}


#Azure Resource Group
resource "azurerm_resource_group" "terrapractice-rg" {
  name     = "terrapractice-resources"
  location = "West US"
  tags = {
    environment = "dev"
  }
}

# Virtual Network
resource "azurerm_virtual_network" "terrapractice-vnet" {
  name                = "terrapractice-vnet"
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  location            = azurerm_resource_group.terrapractice-rg.location
  address_space       = ["10.0.0.0/16"]

  tags = {
    environment = "dev"
  }
}

# Subnet
resource "azurerm_subnet" "terrapractice-subnet" {
  name                 = "terrapractice-subnet"
  resource_group_name  = azurerm_resource_group.terrapractice-rg.name
  virtual_network_name = azurerm_virtual_network.terrapractice-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}



resource "azurerm_network_interface" "terrapractice-nic" {
  name                = "terrapractice-nic"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.terrapractice-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Network Security Group and Rule
resource "azurerm_network_security_group" "terrapractice-nsg" {
  name                = "acceptanceTestSecurityGroup1"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name

  security_rule {
    name                       = "rule1"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "rule2"
    priority                   = 1001
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["80", "443"]
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "dev"
  }
}


# Virtual Machine
resource "azurerm_linux_virtual_machine" "terrapracticeVM" {
  name                = "terrapracticeVM"
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  location            = azurerm_resource_group.terrapractice-rg.location
  size                = "Standard_D2s_v3"
  admin_username      = "adminUser"
  admin_password      = "HelloBrother123!"
  network_interface_ids = [
    azurerm_network_interface.terrapractice-nic.id,
  ]

  admin_ssh_key {
    username   = "adminUser"
    public_key = file("C:/Users/ikibe/.ssh/id_ed25519.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "Debian-11"
    sku       = "11-backports-gen2"
    version   = "latest"
  }
}