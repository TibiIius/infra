terraform {
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.1.0"
    }
  }
}

provider "ct" {}

variable "vm_count" {
  type        = number
  default     = 1
  description = "Number of CoreOS VMs to provision"
}

variable "vm_ips" {
  type        = list(string)
  default     = ["192.168.178.192"]
  description = "List of IP addresses for each CoreOS VM"
}

variable "base_hostname" {
  type        = string
  default     = "coreos-vm"
  description = "Base hostname for VMs (workers append -wn1, -wn2, etc.)"
}

locals {
  vm_names = [
    for i in range(var.vm_count) :
    "${var.base_hostname}-wn${i + 1}"
  ]
}

data "external" "user_data" {
  count = var.vm_count

  program = ["${path.module}/../generate_user_data.sh", "${path.module}/..", var.vm_ips[count.index]]
}

resource "ct_ignition_config" "coreos_config" {
  count  = var.vm_count
  config = data.external.user_data[count.index].result.config
}

output "vm_names" {
  value       = local.vm_names
  description = "Names of CoreOS VMs"
}

output "vm_ips" {
  value       = var.vm_ips
  description = "IP addresses of CoreOS VMs"
}

output "ignition_configs" {
  value       = { for i, cfg in ct_ignition_config.coreos_config : local.vm_names[i] => cfg.json }
  description = "Raw ignition JSON for each CoreOS VM keyed by name"
}
