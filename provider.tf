terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }

  }


  # backend "azurerm" {
  #   resource_group_name  = "sa"
  #   storage_account_name = "123456909090"
  #   container_name       = "tfstate"
  #   key                  = "dev-core-infra.tfstate"
  # }
  backend "azurerm" {}
}

provider "azurerm" {
  features {}

}

