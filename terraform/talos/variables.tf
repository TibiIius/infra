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

variable "node_types" {
  type        = map(string)
  default     = {}
  description = "Map of node IP to node type (controlplane, worker). Defaults to controlplane if not specified."
}
