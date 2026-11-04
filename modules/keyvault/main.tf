# Grants the identity running Terraform full secret management permissions
resource "azurerm_role_assignment" "terraform_deployer" {
  scope                = azurerm_key_vault.kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = var.azure_object_id
}



resource "azurerm_key_vault" "kv" {
  name                        = var.vault_name
  location                    = var.location
  resource_group_name         = var.resource_group_name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id

  # The Standard SKU is incredibly cheap ($0.03 per 10k transactions)
  sku_name = "standard"

  # Production Standard: Use RBAC instead of legacy access policies
  enable_rbac_authorization = true

  # Prevents accidental permanent deletion (Soft Delete is mandatory in Azure now)
  soft_delete_retention_days = 7
  # Close the public network access
  public_network_access_enabled = true

  # Deny everyone EXCEPT your current IP and internal Azure services
  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices"

    # Dynamically injects your laptop's IP address
    ip_rules = var.admin_ip_address != "" ? [var.admin_ip_address] : []
  }

  tags = var.tags

}

# This grants the person (or CI/CD pipeline) running Terraform the right to create secrets
# resource "azurerm_role_assignment" "terraform_user" {
#   scope                = azurerm_key_vault.kv.id
#   role_definition_name = "Key Vault Secrets Officer"
#   principal_id         = var.admin_object_id
#   depends_on          = [azurerm_key_vault.kv]
# }


# This is the DNS zone that will be used by the Private Endpoint. It's a critical piece of the puzzle that allows 
# applications to resolve the private IP address of the Key Vault.

resource "azurerm_private_dns_zone" "kv_dns" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = var.resource_group_name
}


# This is the physical connection.Azure creates a literal Network Interface Card (NIC) inside snet-private-endpoints subnet

resource "azurerm_private_dns_zone_virtual_network_link" "kv_dns_link" {
  name                  = "kv-dns-vnet-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.kv_dns.name

  # Passed in from the VNET module
  virtual_network_id = var.vnet_id
}

# This is the physical connection.
# When you build this resource, Azure creates a literal Network Interface Card (NIC) inside snet-private-endpoints subnet and assigns it a private IP address.
# This is the IP address applications will use to talk to Key Vault.

resource "azurerm_private_endpoint" "kv_pe" {
  name                = "pe-keyvault-prod"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Passed in from the VNET module
  subnet_id = var.pe_subnet_id

  private_service_connection {
    name                           = "kv-privateserviceconnection"
    private_connection_resource_id = azurerm_key_vault.kv.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }

  # This is the DNS zone group that will be used by the Private Endpoint.
  private_dns_zone_group {
    name                 = "kv-dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.kv_dns.id]
  }
}