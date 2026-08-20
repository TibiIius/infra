terraform {
  required_providers {
    talos = {
      source  = "siderolabs/talos"
      version = "~> 0.11"
    }
  }
}

variable "cluster_name" {
  type        = string
  description = "Cluster name"
}

variable "talos_version" {
  type        = string
  description = "Talos version contract used to generate the machine configuration"
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

variable "install_disk" {
  type        = string
  default     = "/dev/sda"
  description = "Disk to install Talos on"
}

variable "client_sans" {
  type        = list(string)
  default     = ["127.0.0.1", "localhost"]
  description = "Client-facing Subject-Alt-Names added to BOTH the machine/apid cert and the Kubernetes API server cert. Needed when clients reach the node via a non-primary address (e.g. a NAT / QEMU loopback port-forward) that differs from the node's own IP."
}

locals {
  endpoint = var.cluster_endpoint != "" ? var.cluster_endpoint : "https://${var.node_ips[0]}:6443"
}

resource "talos_machine_secrets" "cluster" {
  talos_version = var.talos_version
}

data "talos_machine_configuration" "node" {
  for_each = toset(var.node_ips)

  cluster_name     = var.cluster_name
  machine_type     = "controlplane"
  cluster_endpoint = local.endpoint
  machine_secrets  = talos_machine_secrets.cluster.machine_secrets
  talos_version    = var.talos_version
}

data "talos_client_configuration" "cluster" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.cluster.client_configuration
  nodes                = var.node_ips
}

resource "talos_machine_configuration_apply" "node" {
  for_each = toset(var.node_ips)

  client_configuration        = talos_machine_secrets.cluster.client_configuration
  machine_configuration_input = data.talos_machine_configuration.node[each.value].machine_configuration
  node                        = each.value

  config_patches = [
    yamlencode({
      machine = {
        install = {
          disk = var.install_disk
        }
        # Client-facing SAN(s) on the machine/apid cert, so the installed apid is
        # reachable via the loopback hostfwd (127.0.0.1) — not just the node's own
        # IP. Without this the provider cannot complete the mTLS handshake to the
        # installed apid and talos_machine_bootstrap hangs.
        certSANs = var.client_sans
      }
    }),
    # Client-facing SAN(s) on the APIServer cert so kubectl can reach the API via
    # the loopback forward (127.0.0.1) that differs from the node's own IP.
    yamlencode({
      cluster = {
        apiServer = {
          certSANs = var.client_sans
        }
      }
    })
  ]
}

resource "talos_machine_bootstrap" "cluster" {
  depends_on           = [talos_machine_configuration_apply.node]
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.node_ips[0]
}

resource "talos_cluster_kubeconfig" "cluster" {
  depends_on           = [talos_machine_bootstrap.cluster]
  client_configuration = talos_machine_secrets.cluster.client_configuration
  node                 = var.node_ips[0]
}

output "cluster_name" {
  value       = var.cluster_name
  description = "Cluster name"
}

output "cluster_endpoint" {
  value       = local.endpoint
  description = "Talos Kubernetes API endpoint"
}

output "talos_config" {
  value       = data.talos_client_configuration.cluster.talos_config
  description = "Talos client configuration (talosctl talosconfig)"
  sensitive   = true
}

output "machine_configuration" {
  value       = { for ip in var.node_ips : ip => data.talos_machine_configuration.node[ip].machine_configuration }
  description = "Generated machine configuration per node"
  sensitive   = true
}

output "kubeconfig" {
  value       = talos_cluster_kubeconfig.cluster.kubeconfig_raw
  description = "Kubernetes kubeconfig"
  sensitive   = true
}
