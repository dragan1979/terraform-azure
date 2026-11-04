variable "resource_group_name" {
  type        = string
  default     = "vault-rg"
  description = "The name of the Resource Group"
}


variable "tags" {
  type        = map(string)
  description = "A mapping of tags to assign to the resources"
  default     = {}
}


variable "pe_subnet_prefix" {
  type        = string
  default     = "8"
  description = "The address prefixes for the Private Endpoint subnet"
}

variable "region" {
  type        = string
  default     = "italynorth"
  description = "The Azure region"
}


variable "environment" {
  type        = string
  description = "Target deployment environment (e.g., dev, staging, prod)."

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "The environment must be one of: dev, staging, prod."
  }
}

variable "extra_tags" {
  type        = map(string)
  description = "Optional additional tags specific to this environment or deployment."
  default     = {}
}
