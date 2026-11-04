resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.cluster_name
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = var.dns_prefix
  # Gives AKS cluster a cryptographic ID card so Azure Entra ID knows cluster is legitimate.
  oidc_issuer_enabled = true
  # Allows individual pods  to securely injects the secure Azure tokens into pods.
  workload_identity_enabled = true
  private_cluster_enabled   = true


  # Instead of using a third-party tool like ESO, Azure has a built-in add-on for AKS that mounts Key Vault secrets directly
  # into pods as a volume.
  # When retail app pod boots up, the CSI driver uses its built-in feature to automatically sync the Key Vault secret into a native Kubernetes Secret right before the pod starts.
  # The CSI driver has a built-in feature to automatically sync the Key Vault secret into a native Kubernetes Secret right before the pod starts.
  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m" # Automatically checks KV for new values every 2 mins
  }

  default_node_pool {
    name       = "default"
    node_count = var.node_count
    vm_size    = var.vm_size

    # Links the cluster directly to the subnet in aks subnet
    vnet_subnet_id = var.subnet_id
    upgrade_settings {
      drain_timeout_in_minutes      = 0
      max_surge                     = "10%"
      node_soak_duration_in_minutes = 0
    }
  }

  identity {
    # Gives the AKS "brain" the necessary permissions to manage VNet, load balancers, and disks.
    type = "SystemAssigned"
  }
  # Use the NAT Gateway
  network_profile {
    network_plugin = "azure"
    outbound_type  = "userAssignedNATGateway"
    # This puts internal K8s services on a totally different range than VNET,used for internal cluster communication and service discovery
    service_cidr   = "172.16.0.0/16"
    dns_service_ip = "172.16.0.10"
  }
  tags = var.tags
}

# To attach Traefik Load Balancer and to edit AKS security group, the AKS identity must have Network Contributor role on the subnet.
# This allows AKS to assign NAT gateway to the cluster for outbound traffic. 
# This is needed so Azure CCM can create the necessary NSG rules to allow traffic to the Traefik Load Balancer.
resource "azurerm_role_assignment" "aks_subnet_network_contributor" {
  scope                = var.subnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}
