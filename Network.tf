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


# FRONTEND subnet
resource "azurerm_subnet" "FRONTEND_subnet" {
  name                 = "FRONTEND"
  resource_group_name  = azurerm_resource_group.terrapractice-rg.name
  virtual_network_name = azurerm_virtual_network.terrapractice-vnet.name
  address_prefixes     = ["10.0.3.0/24"]
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





# BACKEND subnet
resource "azurerm_subnet" "BACKEND_subnet" {
  name                                      = "BACKEND"
  resource_group_name                       = azurerm_resource_group.terrapractice-rg.name
  virtual_network_name                      = azurerm_virtual_network.terrapractice-vnet.name
  address_prefixes                          = ["10.0.2.0/24"]
  private_endpoint_network_policies = "Enabled"
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
    source_address_prefixes      = azurerm_subnet.FRONTEND_subnet.address_prefixes
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "Deny-Internet-Inbound"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range    = "*"
    source_address_prefix      = "*"
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
  name                = "privatelink.database.core.windows.net"
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "dns_vnet_link" {
  name                  = "sql-dns-vnet-link"
  resource_group_name   = azurerm_resource_group.terrapractice-rg.name
  private_dns_zone_name = azurerm_private_dns_zone.sql-dns.name
  virtual_network_id    = azurerm_virtual_network.terrapractice-vnet.id
}





#Load balancer
# resource "azurerm_public_ip" "loadbalancer" {
#   name                = "PublicIPForLB"
#   location            = azurerm_resource_group.terrapractice-rg.location
#   resource_group_name = azurerm_resource_group.terrapractice-rg.name
#   allocation_method   = "Static"
# }

resource "azurerm_lb" "web_loadbalancer" {
  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.terrapractice-rg.location
  resource_group_name = azurerm_resource_group.terrapractice-rg.name


  frontend_ip_configuration {
    name                          = "LoadbalancerPrivateIPAddress"
    subnet_id                     = azurerm_subnet.FRONTEND_subnet.id
    private_ip_address            = "10.0.3.10"
    private_ip_address_allocation = "Static"
  }

}

resource "azurerm_lb_backend_address_pool" "web" {
  name            = "pool"
  loadbalancer_id = azurerm_lb.web_loadbalancer.id
}

resource "azurerm_lb_probe" "web" {
  loadbalancer_id = azurerm_lb.web_loadbalancer.id
  name            = "web-probe"
  port            = 80
  protocol        = "Tcp"
}

resource "azurerm_lb_rule" "web" {
  loadbalancer_id                = azurerm_lb.web_loadbalancer.id
  name                           = "LBRule"
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  probe_id                       = azurerm_lb_probe.web.id
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.web.id]
  frontend_ip_configuration_name = azurerm_lb.web_loadbalancer.frontend_ip_configuration[0].name
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



#Firewall NAT 
resource "azurerm_firewall_nat_rule_collection" "inbound-web" {
  name                = "inbound-web"
  azure_firewall_name = azurerm_firewall.terrapractice_Firewall.name
  resource_group_name = azurerm_resource_group.terrapractice-rg.name
  priority            = 100
  action              = "Dnat"

  rule {
    name                  = "web-to-lb"
    protocols             = ["TCP"]
    source_addresses      = ["*"]
    destination_addresses = [azurerm_public_ip.Firewall_ip.ip_address]
    destination_ports     = ["80"]
    translated_address    = azurerm_lb.web_loadbalancer.frontend_ip_configuration[0].private_ip_address
    translated_port       = "80"
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


