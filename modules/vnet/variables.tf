variable "vnet_name" {
  type        = string
  description = "The name of the Virtual Network"
}


variable "location" {
  type        = string
  description = "The Azure region"
}

variable "resource_group_name" {
  type        = string
  description = "The name of the Resource Group"
}


variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resources"
  default     = {}
}

variable "aks_subnet_prefix" {
  type        = string
  default     = "4"
  description = "The address prefixes for the AKS subnet"
}

variable "postgres_subnet_prefix" {
  type        = string
  default     = "8"
  description = "The address prefixes for the postgres subnet"
}

variable "pe_subnet_prefix" {
  type        = string
  default     = "8"
  description = "The address prefixes for the Private Endpoint subnet"
}

variable "pipeline_agent_subnet_prefix" {
  type        = string
  default     = "8"
  description = "The address prefixes for the Pipeline Agent subnet"
}



# ---------------------------------------------------------
# Dynamic Network Security Groups (1 per Subnet)
# ---------------------------------------------------------
resource "azurerm_network_security_group" "nsg" {
  for_each = local.subnets

  name                = "nsg-${each.key}"
  location            = var.location
  resource_group_name = var.resource_group_name

  dynamic "security_rule" {
    for_each = each.value.security_rules
    content {
      name                       = security_rule.value.name
      priority                   = security_rule.value.priority
      direction                  = security_rule.value.direction
      access                     = security_rule.value.access
      protocol                   = security_rule.value.protocol
      source_port_range          = security_rule.value.source_port_range
      destination_port_range     = security_rule.value.destination_port_range
      source_address_prefix      = security_rule.value.source_address_prefix
      destination_address_prefix = security_rule.value.destination_address_prefix
    }
  }
}

