#!/usr/bin/env python3
"""
Dynamic inventory script that reads Terraform state for CoreOS VMs
and outputs Ansible-compatible inventory JSON.

Usage:
  python3 terraform_inventory.py --list
  python3 terraform_inventory.py --host <hostname>

Reads from: ../terraform/coreos-vm/terraform.tfstate
"""

import argparse
import json
import os
import sys
from pathlib import Path


def get_tf_state_path():
    script_dir = Path(__file__).resolve().parent
    return script_dir / ".." / "terraform" / "coreos-vm" / "terraform.tfstate"


def load_tf_state(state_path):
    if not state_path.exists():
        return {}
    with open(state_path) as f:
        return json.load(f)


def parse_inventory(state):
    """Parse Terraform state and return inventory dict."""
    inventory = {
        "all": {
            "hosts": ["localhost"],
            "vars": {
                "ansible_connection": "local"
            }
        },
        "homeserver_cluster": {"hosts": []},
        "k8s_home": {"hosts": []},
        "_meta": {
            "hostvars": {}
        }
    }

    if not state.get("outputs"):
        return inventory

    outputs = state["outputs"]

    vm_names = outputs.get("vm_names", {}).get("value", [])
    vm_ips = outputs.get("vm_ips", {}).get("value", [])

    if not vm_names or not vm_ips:
        return inventory

    for name, ip in zip(vm_names, vm_ips):
        inventory["homeserver_cluster"]["hosts"].append(name)
        inventory["k8s_home"]["hosts"].append(name)
        inventory["_meta"]["hostvars"][name] = {
            "ansible_host": ip,
            "ansible_user": "ansible",
            "ansible_connection": "ssh"
        }

    return inventory


def main():
    parser = argparse.ArgumentParser(description="Terraform-based dynamic inventory")
    parser.add_argument("--list", action="store_true", help="List all hosts")
    parser.add_argument("--host", type=str, help="Get variables for a specific host")
    args = parser.parse_args()

    state = load_tf_state(get_tf_state_path())
    inventory = parse_inventory(state)

    if args.list:
        print(json.dumps(inventory, indent=2))
    elif args.host:
        hostvars = inventory.get("_meta", {}).get("hostvars", {})
        host_data = hostvars.get(args.host, {})
        print(json.dumps(host_data, indent=2))
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
