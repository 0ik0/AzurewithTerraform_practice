#Azure Resource Group
resource "azurerm_resource_group" "terrapractice-rg" {
  name     = "terrapractice-resources"
  location = "West US"
  tags = {
    environment = "dev"
  }
}