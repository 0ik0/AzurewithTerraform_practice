# MSSQL Database server
resource "azurerm_mssql_server" "terrapractice_MSSQL" {
  name                         = "mssql-sqlserver"
  resource_group_name          = azurerm_resource_group.terrapractice-rg.name
  location                     = azurerm_resource_group.terrapractice-rg.location
  version                      = "12.0"
  administrator_login          = "TrueAdmini"
  administrator_login_password = var.administrator_login_password
  minimum_tls_version          = "1.2"
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
    prevent_destroy = false
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
    prevent_destroy = false
  }
}