# Agent Instructions

## Repository Purpose

Infrastructure-as-code for managing on-premise (TrueNAS + CoreOS VMs) and cloud
(Hetzner Cloud + Talos) infrastructure.

## Key Conventions

### Naming

- All nodes use `-wn1`, `-wn2`, etc. (1-indexed), even if there's only one node

#### Example

- CoreOS VMs: `coreos-vm-wn1`, `coreos-vm-wn2`
- Talos nodes: `talos-vps-wn1`, `talos-vps-wn2`

### Playbooks

- `bootstrap.yaml` — Full provisioning + configuration (run once)
- `run.yaml` — Idempotent configuration only (run anytime)
- Never mix provisioning and configuration in the same play

### Terraform

- CoreOS: `terraform/coreos-vm/` — ct provider for ignition configs
- Hetzner: `terraform/hetzner/` — hcloud provider for Talos nodes

### Inventory

- Static: `ansible/inventory` — localhost, talos-vps
- Dynamic: `ansible/terraform_inventory.py` — CoreOS VMs from Terraform state
- Never add CoreOS VMs to static inventory

### Secrets

- SOPS (PGP) for confidential files (e.g. Butane config)
- Ansible Vault (Bitwarden via `rbw`) for Ansible vars
- Never commit unencrypted secrets

### CoreOS VMs

- Managed via ignition configs baked into ISOs
- Manual VM creation on TrueNAS, then Ansible configures

### Talos Linux

- No SSH to Talos nodes — managed via `talosctl`

## Development Workflow

```bash
# Setup
mise install
uv sync

# Syntax check
cd ansible && uv run ansible-playbook --syntax-check playbooks/bootstrap.yaml playbooks/run.yaml

# Lint
uv run ansible-lint
```

## Critical Files

- `ansible/playbooks/bootstrap.yaml` — Full bootstrap entry point
- `ansible/playbooks/run.yaml` — Idempotent config entry point
- `ansible/terraform_inventory.py` — Dynamic inventory for CoreOS VMs
- `terraform/coreos-vm/main.tf` — CoreOS ignition generation
- `terraform/hetzner/main.tf` — Hetzner Talos provisioning
- `terraform/generate_user_data.sh` — SOPS decrypt + merge Butane/NM
- `terraform/coreos-vm/create_iso.sh` — coreos-installer Docker wrapper
