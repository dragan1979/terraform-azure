locals {
  base_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "infrastructure-hub"
    Layer       = "compute"
  }
  common_tags = merge(local.base_tags, var.extra_tags)
}

resource "azurerm_resource_group" "aks_rg" {
  name     = "aks-resource-group"
  location = var.region
  tags     = local.common_tags
}

module "aks" {
  source              = "../../modules/aks"
  cluster_name        = "retail-store-aks"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "retail-store-aks"
  subnet_id           = data.azurerm_subnet.aks_nodes.id
  vnet_id             = data.azurerm_virtual_network.vnet.id
  tags                = local.common_tags
  vm_size             = "Standard_E2s_v3"
  node_count          = 2
}