terraform {
  required_providers {
    ct = {
      source  = "poseidon/ct"
      version = "~> 0.1.0"
    }
  }
}

provider "ct" {}

data "external" "user_data" {
  program = ["${path.module}/../generate_user_data.sh", "${path.module}/.."]
}

resource "ct_ignition_config" "coreos_config" {
  config = data.external.user_data.result.config
}

output "ignition_config" {
  value     = ct_ignition_config.coreos_config.rendered
  sensitive = true
  description = "Rendered ignition config for CoreOS VM"
}

output "ignition_config_json" {
  value     = ct_ignition_config.coreos_config.json
  sensitive = true
  description = "Raw ignition JSON for CoreOS VM"
}
