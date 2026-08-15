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
  default     = "talos-home"
  description = "Cluster name"
}

variable "talos_version" {
  type        = string
  default     = "1.7.0"
  description = "Talos Linux version"
}

variable "control_plane_ips" {
  type        = list(string)
  default     = ["192.168.178.192"]
  description = "IP addresses of control plane nodes"
}

variable "worker_ips" {
  type        = list(string)
  default     = []
  description = "IP addresses of worker nodes"
}

variable "cluster_endpoint" {
  type        = string
  default     = ""
  description = "Cluster endpoint (auto-generated from first control plane IP if empty)"
}

locals {
  endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.control_plane_ips[0]}:6443"
  all_ips  = concat(var.control_plane_ips, var.worker_ips)
}

resource "talos_machine_secrets" "home" {
  cluster_name = var.cluster_name
}

resource "talos_machine_config" "control_plane" {
  count = length(var.control_plane_ips)

  secrets = talos_machine_secrets.home

  cluster_endpoint = local.endpoint
  cluster_name     = var.cluster_name
  talos_version    = var.talos_version

  node {
    endpoint        = var.control_plane_ips[count.index]
    control_plane   = true
    install         = true
  }

  output_dir = "${path.module}/generated/cp${count.index}"
}

resource "talos_machine_config" "worker" {
  count = length(var.worker_ips)

  secrets = talos_machine_secrets.home

  cluster_endpoint = local.endpoint
  cluster_name     = var.cluster_name
  talos_version    = var.talos_version

  node {
    endpoint        = var.worker_ips[count.index]
    control_plane   = false
    install         = true
  }

  output_dir = "${path.module}/generated/wn${count.index}"
}

resource "talos_client_config" "home" {
  secrets = talos_machine_secrets.home

  endpoints = var.control_plane_ips

  output_dir = "${path.module}/generated"
}

output "control_plane_ips" {
  value       = var.control_plane_ips
  description = "Control plane node IPs"
}

output "worker_ips" {
  value       = var.worker_ips
  description = "Worker node IPs"
}

output "cluster_endpoint" {
  value       = local.endpoint
  description = "Talos cluster API endpoint"
}

output "config_dir" {
  value       = "${path.module}/generated"
  description = "Directory with generated Talos machine configs"
}
