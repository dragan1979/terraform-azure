variable "resource_group_name" {
  type        = string
  default     = "vault-rg"
  description = "The name of the Resource Group"
}


variable "cluster_name" {
  description = "The name of the Managed Kubernetes Cluster to create."
  type        = string
}

variable "location" {
  description = "The location where the Managed Kubernetes Cluster should be created."
  type        = string
  default     = "westeurope"
}


variable "dns_prefix" {
  description = "DNS prefix specified when creating the managed cluster."
  type        = string
}

variable "subnet_id" {
  description = "The ID of the Subnet where the AKS Cluster should be deployed."
  type        = string
}
variable "vnet_id" {
  type        = string
  description = "The ID of the VNET"
}

variable "tags" {
  description = "A mapping of tags to assign to the resources"
  type        = map(string)
  default     = {}
}

variable "vm_size" {
  description = "The size of the Virtual Machines."
  type        = string
  default     = "Standard_DS2_v2"
}

variable "node_count" {
  description = "The number of nodes for the default node pool."
  type        = number
  default     = 1
}