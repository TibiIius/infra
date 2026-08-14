# Agent Instructions

## Repository Purpose

Infrastructure-as-code for managing on-premise (TrueNAS + Talos VMs) and cloud (Hetzner VPS + Talos) infrastructure. Single OS (Talos), single K8s, single management tool (`talosctl`).

## Key Conventions

### Naming
- All nodes use `-wn1`, `-wn2`, etc. (1-indexed). Never use `cp` suffix.
- Talos nodes: `talos-vps-wn1`, `talos-vps-wn2` (Hetzner)
- Talos VMs: `talos-home-wn1`, `talos-home-wn2` (TrueNAS)

### Playbooks
- `bootstrap.yaml` — Full provisioning + configuration (run once)
- `run.yaml` — Idempotent configuration only (run anytime)
- Never mix provisioning and configuration in the same play

### Terraform
- Hetzner: `terraform/hetzner/` — hcloud provider for Talos nodes
- Always use `node_count` (not `control_plane_count`/`worker_count`)

### Inventory
- Static: `ansible/inventory` — localhost only
- Talos nodes are NOT in Ansible inventory — managed via `talosctl`, not SSH

### Talos Management
- No SSH to Talos nodes. All management via `talosctl` commands run locally.
- TrueNAS VMs: boot Talos installer ISO, then `talosctl apply-config` over network
- Hetzner nodes: cloud-init installs Talos, then `talosctl` applies config

### Secrets
- SOPS (PGP) for Terraform configs
- Ansible Vault (Bitwarden via `rbw`) for Ansible vars
- Never commit unencrypted secrets

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
- `ansible/playbooks/talos/bootstrap.yaml` — Hetzner + TrueNAS Talos provisioning
- `ansible/playbooks/truenas/setup_host.yaml` — TrueNAS health check
- `terraform/hetzner/main.tf` — Hetzner Talos provisioning
- `terraform/hetzner/variables.tf` — node_count, server_type, etc.
