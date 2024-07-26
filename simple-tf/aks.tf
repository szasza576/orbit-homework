
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