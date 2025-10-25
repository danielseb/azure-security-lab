variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "uksouth"
}

variable "resource_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "seclab"
}

variable "admin_username" {
  description = "Admin username for VMs"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/azure_lab_key.pub"
}

variable "allowed_ssh_ip" {
  description = "Your public IP address in CIDR notation (e.g., 203.0.113.45/32)"
  type        = string
  
  validation {
    condition     = can(regex("^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}/\\d{1,2}$", var.allowed_ssh_ip))
    error_message = "Must be a valid IP address in CIDR notation (e.g., 203.0.113.45/32)."
  }
}