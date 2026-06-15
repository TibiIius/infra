# Infrastructure Repository

## Overview

Ansible-based infrastructure-as-code for managing on-premise
(TrueNAS + CoreOS VMs) and cloud (Hetzner Cloud + Talos) infrastructure.

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Hetzner VPS                              │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  Terraform (hcloud) → Ubuntu 26.04                      ││
│  │    ↓ cloud-init                                         ││
│  │  Talos Linux → Full Kubernetes                          ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    TrueNAS (bare-metal)                     │
│  ┌─────────────────────────────────────────────────────────┐│
│  │  CoreOS VM (wn1, wn2, ...)                              ││
│  │    ↓ ignition (baked into ISO via coreos-installer)     ││
│  │  k3s Cluster                                            ││
│  └─────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                    GitOps (separate fleet/ repo)            │
│  Rancher Fleet → deploys to both clusters                   │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
infra/
├── ansible/
│   ├── ansible.cfg              # Ansible config (vault, pipelining)
│   ├── inventory                # Static: localhost, talos-vps
│   ├── terraform_inventory.py   # Dynamic: CoreOS VMs from Terraform state
│   ├── vault-password.sh        # Bitwarden integration (rbw)
│   ├── requirements.yaml        # Ansible Galaxy dependencies
│   ├── playbooks/
│   │   ├── bootstrap.yaml       # Full bootstrap: provision + configure
│   │   ├── run.yaml             # Idempotent config only
│   │   ├── coreos/
│   │   │   ├── bootstrap.yaml   # Terraform → ISOs → pause → add hosts
│   │   │   ├── configure.yaml   # setup_user + coreos_tuning
│   │   │   └── k3s_deploy.yaml  # k3s on homeserver_cluster
│   │   ├── talos/
│   │   │   └── bootstrap.yaml   # Hetzner provision + talosctl
│   │   └── truenas/
│   │       └── setup_host.yaml  # TrueNAS health check
│   ├── roles/
│   │   ├── setup_user/          # CoreOS user creation + SSH + chezmoi
│   │   ├── coreos_tuning/       # CoreOS system tuning (placeholder)
│   │   ├── system/              # Base system (mailserver, future)
│   │   └── docker/              # Docker services (future)
│   └── group_vars/
│       ├── all/                 # Global vars (user, system, network)
│       └── homeserver/          # Homeserver-specific (atuin, paperless)
└── terraform/
    ├── generate_user_data.sh    # SOPS decrypt + merge Butane/NM → JSON
    ├── coreos-vm/
    │   ├── main.tf              # ct provider, ignition generation
    │   ├── config.bu            # SOPS-encrypted Butane config
    │   ├── Wired Connection 1.nmconnection  # SOPS-encrypted NM config
    │   └── create_iso.sh        # coreos-installer Docker wrapper
    └── hetzner/
        ├── main.tf              # hcloud provider, Talos provisioning
        └── variables.tf         # node_count, server_type, etc.
```

## Usage

### Bootstrap (first-time provisioning)

```bash
ansible-playbook -i ansible/terraform_inventory.py ansible/playbooks/bootstrap.yaml
```

### Reconfigure (idempotent drift correction)

```bash
ansible-playbook -i ansible/terraform_inventory.py ansible/playbooks/run.yaml
```

### Dynamic Inventory

```bash
python3 ansible/terraform_inventory.py --list
```

## Key Design Decisions

- **CoreOS VMs**: Managed via Terraform + ignition configs baked into ISOs. Manual VM creation on TrueNAS, then Ansible configures.
- **Talos VPS**: Managed via Terraform (hcloud) + cloud-init for Talos install. No SSH — managed via `talosctl`.
- **Dynamic Inventory**: CoreOS VMs discovered from Terraform state. No static inventory for ephemeral VMs.
- **Naming Convention**: All nodes use `-wn1`, `-wn2`, etc. (1-indexed). No cp/wn split — all nodes are equal.
- **Secrets**: SOPS (PGP) for Terraform/Butane configs. Ansible Vault (Bitwarden via `rbw`) for Ansible vars.

## Dependencies

- **Python**: 3.12 (managed via `uv`)
- **Ansible**: >=12.0.0,<13 (managed via `uv`)
- **Terraform**: For CoreOS ignition and Hetzner provisioning
- **SOPS**: PGP-encrypted configs
- **Docker**: For `coreos-installer` (ISO generation)
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
