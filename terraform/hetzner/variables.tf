variable "hcloud_token" {
  type        = string
  description = "Hetzner Cloud API Token"
  sensitive   = true
}

variable "cluster_name" {
  type        = string
  default     = "talos-vps"
  description = "Base cluster name (nodes append -wn1, -wn2, etc.)"
}

variable "node_count" {
  type        = number
  default     = 1
  description = "Number of Talos nodes"
}

variable "server_type" {
  type        = string
  default     = "cx22"
  description = "Server type (e.g., cx22, cp21)"
}

variable "location" {
  type        = string
  default     = "nbg1"
  description = "Hetzner data center location"
}

variable "talos_version" {
  type        = string
  default     = "1.7.0"
  description = "Talos Linux version to install"
}

variable "environment" {
  type        = string
  default     = "production"
  description = "Environment label for the server"
}
