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

resource "azurerm_resource_group" "DatabaseRG" {
  name     = var.DatabaseResourceGroup
  location = var.Location
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

resource "azurerm_resource_group" "AKSRG" {
  name     = var.AKSResourceGroup
  location = var.Location
}

resource "azurerm_user_assigned_identity" "AKSIdentity" {
  name                = "${var.AKSName}-identity"
  location            = azurerm_resource_group.AKSRG.location
  resource_group_name = azurerm_resource_group.AKSRG.name
}

resource "azurerm_role_assignment" "AKSIdentityRoleAssignment" {
  scope                = azurerm_subnet.BackendSubnet.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.AKSIdentity.principal_id
}

resource "azurerm_log_analytics_workspace" "AKSLogs" {
  name                = "${var.AKSName}-logs"
  location            = azurerm_resource_group.AKSRG.location
  resource_group_name = azurerm_resource_group.AKSRG.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_kubernetes_cluster" "AKSCluster" {
  name                   = var.AKSName
  location               = azurerm_resource_group.AKSRG.location
  resource_group_name    = azurerm_resource_group.AKSRG.name
  depends_on             = [azurerm_role_assignment.AKSIdentityRoleAssignment]
  kubernetes_version     = var.AKSVersion
  dns_prefix             = var.AKSName

  default_node_pool {
    name                = "default"
    vm_size             = var.AKSNodeSKU
    enable_auto_scaling = true
    max_count           = var.AKSNodeMaxCount
    min_count           = 1
    node_count          = 2
    vnet_subnet_id      = azurerm_subnet.BackendSubnet.id
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  api_server_access_profile {
    authorized_ip_ranges = [var.AKSAuthorizedIPs]
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    pod_cidr            = "172.16.0.0/16"
    service_cidr        = "172.17.0.0/16"
    dns_service_ip      = "172.17.0.10"
  }
  oms_agent {
    log_analytics_workspace_id = azurerm_log_analytics_workspace.AKSLogs.id
  }
  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.AKSIdentity.id]
  }

  lifecycle {
    ignore_changes = [ kubernetes_version, default_node_pool[0].node_count ]
  }
}

resource "azurerm_monitor_diagnostic_setting" "AKSDiagnostics" {
  name               = "kube-logs"
  target_resource_id = azurerm_kubernetes_cluster.AKSCluster.id
  log_analytics_workspace_id = azurerm_log_analytics_workspace.AKSLogs.id

  enabled_log {
    category = "kube-apiserver"
  }
  enabled_log {
    category = "kube-audit-admin"
  }
  enabled_log {
    category = "kube-controller-manager"
  }
  enabled_log {
    category = "cluster-autoscaler"
  }
  enabled_log {
    category = "cloud-controller-manager"
  }
  enabled_log {
    category = "guard"
  }
  enabled_log {
    category = "csi-azuredisk-controller"
  }
  enabled_log {
    category = "csi-azurefile-controller"
  }
  enabled_log {
    category = "csi-snapshot-controller"
  }

  metric {
    category = "AllMetrics"
  }
}