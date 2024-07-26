resource "azurerm_resource_group" "VnetRG" {
  name     = var.VnetResourceGroup
  location = var.Location
}

resource "azurerm_network_security_group" "BackendNSG" {
  name                = "${var.BackendSubnetName}-nsg"
  location            = azurerm_resource_group.VnetRG.location
  resource_group_name = azurerm_resource_group.VnetRG.name
}

resource "azurerm_network_security_group" "DatabaseNSG" {
  name                = "${var.DatabaseSubnetName}-nsg"
  location            = azurerm_resource_group.VnetRG.location
  resource_group_name = azurerm_resource_group.VnetRG.name
}

resource "azurerm_virtual_network" "spoke1" {
  name                = var.VnetName
  location            = azurerm_resource_group.VnetRG.location
  resource_group_name = azurerm_resource_group.VnetRG.name
  address_space       = [var.VnetAddressSpace]
}

resource "azurerm_subnet" "BackendSubnet" {
  name                 = var.BackendSubnetName
  resource_group_name  = azurerm_resource_group.VnetRG.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = [var.BackendSubnetIPRange]
}

resource "azurerm_subnet" "DatabaseSubnet" {
  name                 = var.DatabaseSubnetName
  resource_group_name  = azurerm_resource_group.VnetRG.name
  virtual_network_name = azurerm_virtual_network.spoke1.name
  address_prefixes     = [var.DatabaseSubnetIPRange]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "delegation"

    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet_network_security_group_association" "BackendNSGAssociation" {
  subnet_id                 = azurerm_subnet.BackendSubnet.id
  network_security_group_id = azurerm_network_security_group.BackendNSG.id
}

resource "azurerm_subnet_network_security_group_association" "DatabaseNSGAssociation" {
  subnet_id                 = azurerm_subnet.DatabaseSubnet.id
  network_security_group_id = azurerm_network_security_group.DatabaseNSG.id
}

resource "azurerm_private_dns_zone" "DatabasePDNS" {
  name                = "private.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.VnetRG.name
}

resource "azurerm_private_dns_zone_virtual_network_link" "DatabasePDNSLink" {
  name                  = "${var.VnetName}-link"
  private_dns_zone_name = azurerm_private_dns_zone.DatabasePDNS.name
  virtual_network_id    = azurerm_virtual_network.spoke1.id
  resource_group_name   = azurerm_resource_group.VnetRG.name
}
