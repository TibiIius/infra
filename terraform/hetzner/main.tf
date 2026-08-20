terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45.0"
    }
  }
}

provider "hcloud" {
  token = var.hcloud_token
}

resource "hcloud_server" "talos_node" {
  count = var.node_count

  name        = "${var.cluster_name}-node${count.index + 1}"
  image       = "ubuntu-26.04"
  server_type = var.server_type
  location    = var.location

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail
    TALOS_VERSION="${var.talos_version}"

    # Download talosctl
    curl -fsSL "https://github.com/siderolabs/talos/releases/download/v\\${TALOS_VERSION}/talosctl-linux-amd64" -o /usr/local/bin/talosctl
    chmod +x /usr/local/bin/talosctl

    # Generate config and install Talos
    TALOS_DIR="/etc/talos"
    mkdir -p "\\${TALOS_DIR}"
    talosctl gen config talos-vps "https://\\${PRIVATE_IP}:6443" "\\${TALOS_DIR}"
    talosctl install node --config "\\${TALOS_DIR}/machine-config.yaml"
  EOT

  private_net {
    network_id = hcloud_network.talos_network.id
  }

  labels = {
    environment = var.environment
    role        = "talos-node"
  }
}

resource "hcloud_network" "talos_network" {
  name     = "talos-network"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "talos_subnet" {
  network_id   = hcloud_network.talos_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}

output "node_ips" {
  value       = hcloud_server.talos_node[*].ipv4_address
  description = "Public IPv4 addresses of Talos nodes"
}

output "node_private_ips" {
  value       = hcloud_server.talos_node[*].private_net[0].ip_address
  description = "Private IPv4 addresses of Talos nodes"
}
