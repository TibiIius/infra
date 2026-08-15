# Infrastructure Repository

## Overview

Ansible-based infrastructure-as-code for managing on-premise (TrueNAS + Talos VMs) and cloud (Hetzner VPS + Talos) infrastructure. Single OS (Talos), single K8s flavor, single management tool (`talosctl`).

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Hetzner VPS                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Terraform (hcloud) → Ubuntu 26.04                      ││
│  │    ↓ cloud-init → Talos Linux                            ││
│  │  Talos → Full Kubernetes                                ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    TrueNAS (bare-metal)                      │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Talos VM (wn1, wn2, ...)                               ││
│  │    ↓ Terraform generates configs + talosctl apply-config ││
│  │  Full Kubernetes                                        ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    GitOps (fleet/ repo)                      │
│  Rancher Fleet → deploys to both clusters                   │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
infra/
├── ansible/
│   ├── ansible.cfg              # Ansible config (vault, pipelining)
│   ├── inventory                # Static: localhost only
│   ├── vault-password.sh        # Bitwarden integration (rbw)
│   ├── requirements.yaml        # Galaxy dependencies
│   ├── playbooks/
│   │   ├── bootstrap.yaml       # Full bootstrap: provision + configure
│   │   ├── run.yaml             # Idempotent config only
│   │   ├── talos/
│   │   │   └── bootstrap.yaml   # Hetzner + TrueNAS Talos provisioning
│   │   └── truenas/
│   │       └── setup_host.yaml  # TrueNAS health check
│   ├── roles/
│   │   ├── system/              # Base system (mailserver, future)
│   │   └── docker/              # Docker services (future)
│   └── group_vars/
│       └── all/                 # Global vars (user, system, network)
└── terraform/
    ├── hetzner/
    │   ├── main.tf              # hcloud provider, Talos provisioning
    │   └── variables.tf         # node_count, server_type, etc.
    └── talos-home/
        ├── main.tf              # siderolabs/talos provider, machine config generation
        └── generated/           # Generated Talos machine configs (gitignored)
```

## Usage

### Bootstrap (first-time provisioning)

```bash
ansible-playbook ansible/playbooks/bootstrap.yaml
```

### Reconfigure (idempotent drift correction)

```bash
ansible-playbook ansible/playbooks/run.yaml
```

## Key Design Decisions

- **Talos everywhere**: Both Hetzner VPS and TrueNAS VMs run Talos. No CoreOS/k3s.
- **No SSH to Talos nodes**: Managed entirely via `talosctl`. No Ansible inventory for Talos nodes.
- **TrueNAS VMs**: Terraform generates Talos machine configs, you boot VMs with installer ISO, then `talosctl apply-config` over the network.
- **Naming Convention**: All nodes use `-wn1`, `-wn2`, etc. (1-indexed). No cp/wn split.
- **Secrets**: SOPS (PGP) for Terraform configs. Ansible Vault (Bitwarden via `rbw`) for Ansible vars.

## Dependencies

- **Python**: 3.12 (managed via `uv`)
- **Ansible**: >=12.0.0,<13
- **Terraform**: For Hetzner provisioning
- **SOPS**: PGP-encrypted configs
- **talosctl**: Talos Linux management
- **mise**: Tool version management

## Development

```bash
# Setup
mise install
uv sync

# Syntax check
cd ansible && uv run ansible-playbook --syntax-check playbooks/bootstrap.yaml playbooks/run.yaml

# Lint
uv run ansible-lint
```
