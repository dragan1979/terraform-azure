locals {
  base_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "infrastructure-hub"
    Layer       = "network"
  }
  common_tags = merge(local.base_tags, var.extra_tags)
}

resource "azurerm_resource_group" "vault_rg" {
  name     = "rg-security-hub"
  location = var.region
  tags     = local.common_tags
}

resource "azurerm_resource_group" "vnet_rg" {
  name     = "vnet-rg"
  location = var.region
  tags     = local.common_tags
}

module "vnet" {
  source              = "../../modules/vnet"
  vnet_name           = "infra-vnet"
  location            = var.region
  resource_group_name = azurerm_resource_group.vnet_rg.name
  vnet_cidr           = "10.100.0.0/16"
  tags                = local.common_tags

}

