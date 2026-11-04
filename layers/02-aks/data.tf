data "azurerm_virtual_network" "vnet" {
  name                = "infra-vnet"
  resource_group_name = "vnet-rg"
}

data "azurerm_subnet" "aks_nodes" {
  name                 = "snet-aks-nodes"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_virtual_network.vnet.resource_group_name
}