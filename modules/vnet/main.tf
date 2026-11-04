variable "vnet_cidr" {
  type    = string
  default = "10.100.0.0/16"
}

locals {
  # Base Subnet Definitions (NO references to calculated CIDRs here)
  subnet_base_specs = [
    {
      name                = "snet-aks-nodes"
      newbits             = var.aks_subnet_prefix # /20
      delegation          = null
      nat_gateway_enabled = true
    },
    {
      name                = "snet-db"
      newbits             = var.postgres_subnet_prefix # /24
      delegation          = "Microsoft.DBforPostgreSQL/flexibleServers"
      nat_gateway_enabled = false
    },
    {
      name                = "snet-private-endpoints"
      newbits             = var.pe_subnet_prefix # /24
      delegation          = null
      nat_gateway_enabled = false
    },
    {
      name                = "snet-devops-agent"
      newbits             = var.pipeline_agent_subnet_prefix # /24
      delegation          = null
      nat_gateway_enabled = false
    }
  ]

  # Calculate CIDRs strictly from the base definitions


  # it extracts an array of subnet bit sizes, expands that array into individual function parameters, and calculates contiguous, collision-free CIDR blocks.
  # cidrsubnets does not accept a list. It expects each newbits number as a distinct, separated parameter.
  # Without ...:
  # BAD PRACTICE: Uses list of numbers
  # Produces a single list: [4, 8, 8, 8]
  # ERROR: Invalid function argument: expected number, got tuple.
  # With ...:
  # Expands automatically to list cidrsubnets(var.vnet_cidr, 4, 8, 8, 8)

  # [for s in local.subnet_base_specs : s.newbits]
  # Terraform iterates over your list of objects and pulls out only the integer value of newbits.
  # Input:
  # local.subnet_base_specs = [
  #   { name = "snet-aks-nodes",        newbits = 4, ... },
  #   { name = "snet-db",               newbits = 8, ... },
  #   { name = "snet-private-endpoints",newbits = 8, ... },
  #   { name = "snet-devops-agent",     newbits = 8, ... }
  # ]

  # # Output of the list comprehension:
  # [4, 8, 8, 8]
  # Phase 2: Argument Unpacking with ... (Expansion Operator)
  # The cidrsubnets() function expects comma-separated numbers, not a single list variable.
  # cidrsubnets(var.vnet_cidr, 4, 8, 8, 8) # ERROR: expected number, got tuple
  # cidrsubnets(var.vnet_cidr, [4, 8, 8, 8]) # ERROR: expected number, got list

  # # What '...' does:
  # cidrsubnets(var.vnet_cidr, [4, 8, 8, 8]...) 
  # # Expands to:
  # cidrsubnets("10.100.0.0/16", 4, 8, 8, 8)
  # Cidrsubnets evaluates each bit increment sequentially from left to right, maintaining a pointer to the next free IP address:
  # 4 (newbits): Adds 4 bits to /16 -> creates a /20 block (4,096 IPs).
  # Spans 10.100.0.0 through 10.100.15.255.
  # Result: 10.100.0.0/20.
  # Cursor moves to 10.100.16.0
  # 8 (newbits): Adds 8 bits to /16 -> creates a /24 block (256 IPs).
  # Spans 10.100.16.0 through 10.100.16.255.
  # Result: 10.100.16.0/24.
  # Cursor moves to 10.100.17.0.
  # 8 (newbits): Adds 8 bits to /16 -> creates the next /24 block.
  # Spans 10.100.17.0 through 10.100.17.255.
  # Result: 10.100.17.0/24.
  # Cursor moves to 10.100.18.0.
  # 8 (newbits): Adds 8 bits to /16 -> creates the next /24 block.
  # Spans 10.100.18.0 through 10.100.18.255.
  # Result: 10.100.18.0/24.
  # The variable local.calculated_cidrs holds an indexed array of calculated CIDR strings:
  #[
  #   "10.100.0.0/20",   # index 0: snet-aks-nodes
  #   "10.100.16.0/24",  # index 1: snet-db
  #   "10.100.17.0/24",  # index 2: snet-private-endpoints
  #   "10.100.18.0/24"   # index 3: snet-devops-agent
  # ]



  calculated_cidrs = cidrsubnets(var.vnet_cidr, [for s in local.subnet_base_specs : s.newbits]...)






  # Helper variables to make NSG rules clear and self-documenting
  aks_cidr          = local.calculated_cidrs[0]
  db_cidr           = local.calculated_cidrs[1]
  endpoints_cidr    = local.calculated_cidrs[2]
  devops_agent_cidr = local.calculated_cidrs[3]


  ## NSG ######

  # Assemble the final map with CIDRs AND NSG rules together
  subnets = {
    "snet-aks-nodes" = {
      cidr       = local.aks_cidr
      delegation = null
      # Deny traffic from inside the VNet
      security_rules = [
        {
          name                       = "AllowIntraSubnet"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "VirtualNetwork"
        },
        # Allow API Server from Jumpbox deployed in DevOps Agent subnet
        {
          name                       = "AllowAPIServerFromManagement"
          priority                   = 110
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = local.devops_agent_cidr # or GatewaySubnet CIDR
          destination_address_prefix = local.aks_cidr
        }
      ]
    }
    # Allow only Postgres from AKS
    "snet-db" = {
      cidr       = local.db_cidr
      delegation = "Microsoft.DBforPostgreSQL/flexibleServers"
      security_rules = [
        {
          name                       = "AllowPostgresFromAKS"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "5432"
          source_address_prefix      = local.aks_cidr
          destination_address_prefix = "*"
        },
        {
          name                       = "DenyAllOtherInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
    }
    # Allow only HTTPS inside the VNet
    "snet-private-endpoints" = {
      cidr       = local.endpoints_cidr
      delegation = null
      security_rules = [
        {
          name                       = "AllowHTTPSFromAKSAndAgent"
          priority                   = 100
          direction                  = "Inbound"
          access                     = "Allow"
          protocol                   = "Tcp"
          source_port_range          = "*"
          destination_port_range     = "443"
          source_address_prefix      = "VirtualNetwork"
          destination_address_prefix = "*"
        },
        {
          name                       = "DenyAllOtherInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "*"
          destination_address_prefix = "*"
        }
      ]
    }

    "snet-devops-agent" = {
      cidr       = local.devops_agent_cidr
      delegation = null
      security_rules = [
        {
          name                       = "DenyDirectInternetInbound"
          priority                   = 4096
          direction                  = "Inbound"
          access                     = "Deny"
          protocol                   = "*"
          source_port_range          = "*"
          destination_port_range     = "*"
          source_address_prefix      = "Internet"
          destination_address_prefix = "*"
        }

      ]
    }
  }
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags                = var.tags

}

resource "azurerm_subnet" "subnets" {
  for_each = local.subnets

  name                 = each.key
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [each.value.cidr]

  dynamic "delegation" {
    for_each = each.value.delegation != null ? [each.value.delegation] : []
    content {
      name = "delegation-${each.key}"
      service_delegation {
        name = delegation.value
        actions = [
          "Microsoft.Network/virtualNetworks/subnets/join/action",
        ]
      }
    }
  }
}

# # Public IP
resource "azurerm_public_ip" "nat_gw_ip" {
  name                = "pip-nat-gw"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# # Single NAT Gateway (~$32/month)
resource "azurerm_nat_gateway" "nat_gw" {
  name                = "nat-gw-shared"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "Standard"
}

# # Bind IP to NAT Gateway
resource "azurerm_nat_gateway_public_ip_association" "nat_ip_assoc" {
  nat_gateway_id       = azurerm_nat_gateway.nat_gw.id
  public_ip_address_id = azurerm_public_ip.nat_gw_ip.id
}

# Associate the single NAT Gateway to multiple subnets via for_each
# The toset() function converts a list into a set of unique values.
# Terraform's for_each statement has a strict type requirement:
# for_each only accepts a map or a set of strings. It will throw a fatal syntax error if you pass a standard list.


# If nat_gateway_enabled exists and is true --> included in the set.If nat_gateway_enabled is false or completely missing --> safely treated as false and excluded without errors.

locals {
  subnets_with_nat = toset([
    for s in local.subnet_base_specs : s.name if try(s.nat_gateway_enabled, false)
  ])
}

resource "azurerm_subnet_nat_gateway_association" "nat_assoc" {
  for_each = local.subnets_with_nat

  subnet_id      = azurerm_subnet.subnets[each.key].id
  nat_gateway_id = azurerm_nat_gateway.nat_gw.id
}



# ---------------------------------------------------------
# Dynamic NSG to Subnet Association
# ---------------------------------------------------------
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}