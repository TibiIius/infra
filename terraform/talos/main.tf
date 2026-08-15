terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 1.7"
    }
  }
}

provider "talos" {
  config_path = "${path.module}/generated"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "talos_version" {
  type        = string
  default     = "1.7.0"
  description = "Talos Linux version"
}

variable "node_ips" {
  type        = list(string)
  description = "IP addresses of cluster nodes"
}

variable "cluster_endpoint" {
  type        = string
  default     = ""
  description = "Cluster endpoint (auto-generated from first node IP if empty)"
}

locals {
  endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.node_ips[0]}:6443"
}

resource "talos_machine_secrets" "cluster" {
  cluster_name = var.cluster_name
}

resource "talos_machine_config" "node" {
  count = length(var.node_ips)

  secrets = talos_machine_secrets.cluster

  cluster_endpoint = local.endpoint
  cluster_name     = var.cluster_name
  talos_version    = var.talos_version

  node {
    endpoint        = var.node_ips[count.index]
    control_plane   = true
    install         = true
  }

  output_dir = "${path.module}/generated/node${count.index}"
}

resource "talos_client_config" "cluster" {
  secrets = talos_machine_secrets.cluster

  endpoints = var.node_ips

  output_dir = "${path.module}/generated"
}

output "node_ips" {
  value       = var.node_ips
  description = "Cluster node IPs"
}

output "cluster_endpoint" {
  value       = local.endpoint
  description = "Talos Kubernetes API endpoint"
}

output "config_dir" {
  value       = "${path.module}/generated"
  description = "Directory with generated Talos machine configs"
}
