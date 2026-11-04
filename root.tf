
# Fetches the public IP address of the machine running Terraform
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

# Getting the current client configuration for the Azure provider (E.g. Tenant ID, Subscription ID, etc.)
data "azurerm_client_config" "current" {}

locals {
  # Baseline tags common across every deployment
  base_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "infrastructure-hub"
    Owner       = "cloud-engineering"
  }

  # Merged tags: base tags + any environment-specific overrides
  common_tags = merge(local.base_tags, var.extra_tags)
}


resource "azurerm_resource_group" "vault_rg" {
  name     = "rg-security-hub"
  location = var.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "vnet-rg" {
  name     = "vnet-rg"
  location = var.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "aks_rg" {
  name     = "aks-resource-group"
  location = var.region
  tags     = local.common_tags
}

module "vnet" {
  source = "./modules/vnet"

  vnet_name           = "infra-vnet"
  location            = var.region
  resource_group_name = "vnet-rg"
  vnet_cidr           = "10.100.0.0/16"
  depends_on          = [azurerm_resource_group.vnet-rg]
  tags                = local.common_tags

}

# module "keyvault" {
#   source              = "./modules/keyvault"
#   vault_name          = "kv-hub-prod-unique23456"
#   resource_group_name = azurerm_resource_group.vault_rg.name
#   location            = azurerm_resource_group.vault_rg.location
#   vnet_id             = module.vnet.vnet_id
#   pe_subnet_id        = module.vnet.subnets["snet-private-endpoints"].id
#   admin_ip_address    = "${chomp(data.http.my_ip.response_body)}/32"

#   # Pass current Object ID and Tenant ID to the module
#   tenant_id           = data.azurerm_client_config.current.tenant_id
#   azure_object_id     = data.azurerm_client_config.current.object_id
#   # subscription_id     = data.azurerm_client_config.current.subscription_id
#   tags                = local.common_tags
# }

module "aks" {
  source              = "./modules/aks"
  cluster_name        = "retail-store-aks"
  location            = azurerm_resource_group.aks_rg.location
  resource_group_name = azurerm_resource_group.aks_rg.name
  dns_prefix          = "retail-store-aks"
  subnet_id           = module.vnet.subnets["snet-aks-nodes"].id
  tags                = local.common_tags
  vm_size             = "standard_b2s_v2"
  node_count          = 2
  vnet_id             = module.vnet.vnet_id
  depends_on          = [module.vnet]
}




output "subnets" {
  value = module.vnet.subnets
}