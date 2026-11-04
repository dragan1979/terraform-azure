variable "region" {
  type        = string
  default     = "northeurope"
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