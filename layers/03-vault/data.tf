# 1. Network lookups (retrieves resources provisioned by 01-network)
data "azurerm_virtual_network" "vnet" {
  name                = "infra-vnet"
  resource_group_name = "vnet-rg"
}

data "azurerm_subnet" "pe_subnet" {
  name                 = "snet-private-endpoints"
  virtual_network_name = data.azurerm_virtual_network.vnet.name
  resource_group_name  = data.azurerm_virtual_network.vnet.resource_group_name
}

# Fetches the public IP address of the machine running Terraform
data "http" "my_ip" {
  url = "https://ifconfig.me/ip"
}

# Getting the current client configuration for the Azure provider (E.g. Tenant ID, Subscription ID, etc.)
data "azurerm_client_config" "current" {}