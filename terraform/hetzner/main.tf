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
  name        = var.server_name
  image       = "ubuntu-22.04"
  server_type = var.server_type
  location    = var.location

  user_data = <<-EOT
    #!/bin/bash
    set -euo pipefail

    # Install Talos
    TALOS_VERSION="${talos_version}"
    TALOSCTL_URL="https://github.com/siderolabs/talos/releases/download/v\${TALOS_VERSION}/talosctl-linux-amd64"

    # Download and install talosctl
    curl -fsSL "\${TALOSCTL_URL}" -o /usr/local/bin/talosctl
    chmod +x /usr/local/bin/talosctl

    # Generate Talos configuration
    TALOS_DIR="/etc/talos"
    mkdir -p "\${TALOS_DIR}"

    talosctl gen config talos-vps "https://\${PRIVATE_IP}:6443" "\${TALOS_DIR}"

    # Install Talos to disk
    talosctl install node --config "\${TALOS_DIR}/machine-config.yaml"

    # Reboot into Talos
    systemctl reboot
  EOT

  private_net {
    network_id = hcloud_network.talos_network.id
  }

  labels = {
    environment = var.environment
    role        = "talos-control-plane"
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

output "server_ipv4" {
  value       = hcloud_server.talos_node.ipv4_address
  description = "Public IPv4 address of the Talos VPS"
}

output "server_private_ipv4" {
  value       = hcloud_server.talos_node.private_net[0].ip_address
  description = "Private IPv4 address of the Talos VPS"
}

output "talos_endpoint" {
  value       = "https://${hcloud_server.talos_node.private_net[0].ip_address}:6443"
  description = "Talos Kubernetes API endpoint"
}
