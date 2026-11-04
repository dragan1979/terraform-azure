locals {
  base_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Project     = "infrastructure-hub"
    Layer       = "compute"
  }
  common_tags = merge(local.base_tags, var.extra_tags)
}

resource "azurerm_resource_group" "vault_rg" {
  name     = var.resource_group_name
  location = var.region
  tags     = local.common_tags
}

module "keyvault" {
  source              = "../../modules/keyvault"
  vault_name          = "kv-hub-prod-unique23456"
  resource_group_name = azurerm_resource_group.vault_rg.name
  location            = azurerm_resource_group.vault_rg.location
  vnet_id             = data.azurerm_virtual_network.vnet.id
  pe_subnet_id        = data.azurerm_subnet.pe_subnet.id
  admin_ip_address    = "${chomp(data.http.my_ip.response_body)}/32"

  #   # Pass current Object ID and Tenant ID to the module
  tenant_id       = data.azurerm_client_config.current.tenant_id
  azure_object_id = data.azurerm_client_config.current.object_id
  # subscription_id     = data.azurerm_client_config.current.subscription_id
  tags = local.common_tags
}