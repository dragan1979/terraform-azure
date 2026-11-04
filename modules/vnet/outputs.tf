output "subnets" {

  value = {
    for name, subnet in azurerm_subnet.subnets : name => {
      name = subnet.name
      id   = subnet.id
      cidr = subnet.address_prefixes[0]
    }
  }
}


output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {

  value = azurerm_virtual_network.vnet.name

}