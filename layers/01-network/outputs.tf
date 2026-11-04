output "vnet_name" {
  description = "The name of the Virtual Network"
  value       = module.vnet.vnet_name
}

output "vnet_resource_group_name" {
  value       = azurerm_resource_group.vnet_rg.name
  description = "Resource group where the VNet resides"
}

output "aks_subnet_id" {
  value       = module.vnet.subnets["snet-aks-nodes"].id
  description = "Resource ID of the subnet dedicated to AKS nodes"
}

output "vnet_id" {
  value       = module.vnet.vnet_id
  description = "Resource ID of the Virtual Network"
}