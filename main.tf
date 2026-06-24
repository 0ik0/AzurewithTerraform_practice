variable "subscription_id" { type = string }
variable "client_id" { type = string }
variable "client_secret" { type = string }
variable "tenant_id" { type = string }
variable "admin_password" { type = string }
variable "administrator_login_password" { type = string }


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



# Database subnet
resource "azurerm_subnet" "BACKEND_subnet" {
  name                 = "BACKEND"
  resource_group_name  = azurerm_resource_group.terrapractice-rg.name
  virtual_network_name = azurerm_virtual_network.terrapractice-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}


# Network Security Group and Rule
resource "azurerm_network_security_group" "BACKEND_nsg" {
  name                = "BACKEND-nsg1"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name

  security_rule {
    name                       = "Allow-from-FRONTEND"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "1433"
    source_address_prefix      = "10.0.1.0/24"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["*"]
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "dev"
  }
}

resource "azurerm_subnet_network_security_group_association" "BACKEND_nsg_assoc" {
  subnet_id                 = azurerm_subnet.BACKEND_subnet.id
  network_security_group_id = azurerm_network_security_group.BACKEND_nsg.id
}



# MSSQL Database server
resource "azurerm_mssql_server" "terrapractice_MSSQL" {
  name                         = "mssql-sqlserver"
  resource_group_name          = azurerm_resource_group.terrapractice-rg.name
  location                     = azurerm_resource_group.terrapractice-rg.location
  version                      = "12.0"
  administrator_login          = "Administrator"
  administrator_login_password = var.administrator_login_password
}

resource "azurerm_mssql_database" "first_mssql-database" {
  name         = "terrapractice-db"
  server_id    = azurerm_mssql_server.terrapractice_MSSQL.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    environment = "dev"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}


# MSSQL DatabaseII
resource "azurerm_mssql_database" "second_mssql-database" {
  name         = "terrapractice-db-2"
  server_id    = azurerm_mssql_server.terrapractice_MSSQL.id
  collation    = "SQL_Latin1_General_CP1_CI_AS"
  license_type = "LicenseIncluded"
  max_size_gb  = 2
  sku_name     = "S0"
  enclave_type = "VBS"

  tags = {
    environment = "dev"
  }

  # prevent the possibility of accidental data loss
  lifecycle {
    prevent_destroy = true
  }
}

#MSSQL firewall
resource "azurerm_mssql_firewall_rule" "terrapractice-rg" {
  name             = "FirewallRule1"
  server_id        = azurerm_mssql_server.terrapractice_MSSQL.id
  start_ip_address = "10.0.17.62"
  end_ip_address   = "10.0.17.62"
}


#Private endpoint and DNS
resource "azurerm_private_endpoint" "privateendpoint" {
  name                = "example-endpoint"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  subnet_id           = azurerm_subnet.BACKEND_subnet.id

  private_service_connection {
    name                           = "sqldatabase-privateserviceconnection"
    private_connection_resource_id = azurerm_mssql_server.terrapractice_MSSQL.id
    subresource_names              = ["sqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "sql-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.sql-dns.id]
  }
}

resource "azurerm_private_dns_zone" "sql-dns" {
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "sql-dns-vnet-link"
  resource_group_name   = azurerm_resource_group.terrapractice-rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql-dns.name
  virtual_network_id    = azurerm_virtual_network.terrapractice-vnet.id
}



# FRONTEND subnet
resource "azurerm_subnet" "FRONTEND_subnet" {
  name                 = "FRONTEND"
  resource_group_name  = azurerm_resource_group.terrapractice-rg.name
  virtual_network_name = azurerm_virtual_network.terrapractice-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Network Security Group and Rule
resource "azurerm_network_security_group" "FRONTEND_nsg" {
  name                = "FRONTEND-nsg1"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name

  security_rule {
    name                       = "Allow-HTTP-from-Internet"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Allow-HTTPS-from-Internet"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }
  tags = {
    environment = "dev"
  }
}


#FRONTEND_nsg_association
resource "azurerm_subnet_network_security_group_association" "FRONTEND_nsg_assoc" {
  subnet_id                 = azurerm_subnet.FRONTEND_subnet.id
  network_security_group_id = azurerm_network_security_group.FRONTEND_nsg.id
}


#Load balancer
resource "azurerm_public_ip" "loadbalancer" {
  name                = "PublicIPForLB"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  allocation_method   = "Static"
}

resource "azurerm_lb" "web_loadbalancer" {
  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.loadbalancer.id
  }
}



#Scaleable VMs
resource "azurerm_linux_virtual_machine_scale_set" "terrapractice-rg" {
  name                            = "terrapractice-vmss"
  resource_group_name             = azurerm_resource_group.terrapractice-rg.name
  location                        = azurerm_resource_group.terrapractice-rg.location
  sku                             = "Standard_F2"
  instances                       = 1
  admin_username                  = "adminuser"
  admin_password                  = var.admin_password
  disable_password_authentication = false

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  network_interface {
    name    = "terrapractice_netInterface"
    primary = true

    ip_configuration {
      name      = "FRONTEND_subnet"
      primary   = true
      subnet_id = azurerm_subnet.FRONTEND_subnet.id
    }
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  # Since these can change via auto-scaling outside of Terraform,
  # let's ignore any changes to the number of instances
  lifecycle {
    ignore_changes = [instances]
  }
}

#Scalable VM monitor
resource "azurerm_monitor_autoscale_setting" "terrapractice-rg" {
  name                = "autoscale-config"
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  location            = azurerm_resource_group.terrapractice-rg.location
  target_resource_id  = azurerm_linux_virtual_machine_scale_set.terrapractice-rg.id

  profile {
    name = "AutoScale"

    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.terrapractice-rg.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 75
      }

      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }

    rule {
      metric_trigger {
        metric_name        = "Percentage CPU"
        metric_resource_id = azurerm_linux_virtual_machine_scale_set.terrapractice-rg.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 25
      }

      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }
}


#Firewall SUBNET
resource "azurerm_subnet" "terrapractice_firewall_subnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.terrapractice-rg.name
  virtual_network_name = azurerm_virtual_network.terrapractice-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#Public IP
resource "azurerm_public_ip" "Firewall_ip" {
  name                = "testpip"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

#Firewall
resource "azurerm_firewall" "terrapractice_Firewall" {
  name                = "firewall"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Standard"

  ip_configuration {
    name                 = "firewall_configuration"
    subnet_id            = azurerm_subnet.terrapractice_firewall_subnet.id
    public_ip_address_id = azurerm_public_ip.Firewall_ip.id
  }
}


#Route table
resource "azurerm_route_table" "terra_route_table" {
  name                = "routetable1"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name

  route {
    name                   = "Outbound"
    address_prefix         = "0.0.0.0/0"
    next_hop_type          = "VirtualAppliance"
    next_hop_in_ip_address = azurerm_firewall.terrapractice_Firewall.ip_configuration[0].private_ip_address
  }
}

resource "azurerm_subnet_route_table_association" "FRONTEND_route_table" {
  subnet_id      = azurerm_subnet.FRONTEND_subnet.id
  route_table_id = azurerm_route_table.terra_route_table.id
}

resource "azurerm_subnet_route_table_association" "BACKEND_route_table" {
  subnet_id      = azurerm_subnet.BACKEND_subnet.id
  route_table_id = azurerm_route_table.terra_route_table.id
}

