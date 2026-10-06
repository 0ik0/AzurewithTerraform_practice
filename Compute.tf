#Scaleable VMs
resource "azurerm_linux_virtual_machine_scale_set" "terrapractice-rg" {
  name                            = "terrapractice-vmss"
  resource_group_name             = azurerm_resource_group.terrapractice-rg.name
  location                        = azurerm_resource_group.terrapractice-rg.location
  sku                             = "Standard_D8s_v3"
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
      name                                   = "FRONTEND_subnet"
      primary                                = true
      subnet_id                              = azurerm_subnet.FRONTEND_subnet.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.web.id]
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
