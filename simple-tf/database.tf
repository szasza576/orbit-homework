resource "azurerm_resource_group" "DatabaseRG" {
  name     = var.DatabaseResourceGroup
  location = var.Location
}

resource "azurerm_postgresql_flexible_server" "Database" {
  name                          = var.DatabaseName
  location                      = azurerm_resource_group.DatabaseRG.location
  resource_group_name           = azurerm_resource_group.DatabaseRG.name
  version                       = "16"
  delegated_subnet_id           = azurerm_subnet.DatabaseSubnet.id
  private_dns_zone_id           = azurerm_private_dns_zone.DatabasePDNS.id
  public_network_access_enabled = false
  administrator_login           = var.DatabaseAdmin
  administrator_password        = var.DatabasePassword
  zone                          = 1

  storage_mb   = 32768
  storage_tier = "P4"

  sku_name   = "B_Standard_B1ms"
  depends_on = [azurerm_private_dns_zone_virtual_network_link.DatabasePDNSLink]
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "DatabaseFirewallRule" {
  name             = "AllowAKS"
  server_id        = azurerm_postgresql_flexible_server.Database.id
  start_ip_address = cidrhost(var.BackendSubnetIPRange, 0)
  end_ip_address   = cidrhost(var.BackendSubnetIPRange, -1)
}
