#!/usr/bin/env bash
#
# bringup.sh — bring up a single-node Talos control plane in QEMU and verify it.
#
# This is the reproducible test for the `talos-home` cluster: it boots a
# Talos installer VM, applies the control-plane config, bootstraps etcd, and
# confirms the node reports Ready via kubectl.
#
# Designed to run both locally and in CI
# Exits non-zero on any failure. All state is written under $WORKDIR and cleaned
# up on exit (unless KEEP_VM=1).
#
# Overridables (env vars):
#   TALOS_VERSION   default v1.13.8
#   TALOS_ISO       path to metal-amd64.iso (downloaded if absent)
#   WORKDIR         scratch dir (default: mktemp)
#   NODE_IP         guest IP on the slirp net (default 10.0.2.15, deterministic)
#   API_PORT        Talos apid port to forward (default 50000)
#   K8S_PORT        Kubernetes API port to forward (default 6443)
#   MEM_MB / SMP    VM resources (default 512 / 1)
#   KEEP_VM=1       leave the QEMU process running after the test
#
set -euo pipefail

# --- Configuration -----------------------------------------------------------
TALOS_VERSION="${TALOS_VERSION:-v1.13.8}"
WORKDIR="${WORKDIR:-$(mktemp -d /tmp/talos-home-test.XXXXXX)}"
ISO="${TALOS_ISO:-$WORKDIR/metal-amd64.iso}"
NODE_IP="${NODE_IP:-10.0.2.15}"
API_PORT="${API_PORT:-50000}"
K8S_PORT="${K8S_PORT:-6443}"
MEM_MB="${MEM_MB:-512}"
SMP="${SMP:-1}"
DISK="$WORKDIR/disk.qcow2"
BOOT="$WORKDIR/boot"
SERIAL="$WORKDIR/serial.log"
TALOSCTL="${TALOSCTL:-talosctl}"
KUBECTL="${KUBECTL:-kubectl}"
export TALOSCONFIG="$WORKDIR/talosconfig"

# Kernel cmdline for the installer boot. Must include the KSPP-required params
# (slab_nomerge, pti=on) or Talos aborts in the systemRequirements phase.
# Based on the ISO's own grub.cfg; we add a serial console for logs.
KERNEL_CMDLINE="${KERNEL_CMDLINE:-talos.platform=metal console=tty0 console=ttyS0,115200n8 talos.halt_if_installed=1 init_on_alloc=1 slab_nomerge pti=on consoleblank=0 nvme_core.io_timeout=4294967295 printk.devkmsg=on selinux=1 module.sig_enforce=1 proc_mem.force_override=never}"

log() { printf '\n\033[1;34m[bringup]\033[0m %s\n' "$*"; }
die() { printf '\n\033[1;31m[bringup][err]\033[0m %s\n' "$*" >&2; dump_serial; exit 1; }
dump_serial() { if [[ -f "$SERIAL" ]]; then printf '\n--- serial.log (tail) ---\n'; tail -n 60 "$SERIAL" >&2 || true; fi; }

QEMU_PID=""
cleanup() {
  if [[ "${KEEP_VM:-0}" == "1" ]]; then log "KEEP_VM=1 — leaving QEMU pid ${QEMU_PID:-?} running"; return 0; fi
  [[ -n "$QEMU_PID" ]] && kill "$QEMU_PID" 2>/dev/null || true
}
trap cleanup EXIT

# --- 0. Prerequisites --------------------------------------------------------
for t in "$TALOSCTL" "$KUBECTL" qemu-system-x86_64 qemu-img curl python3; do
  command -v "$t" >/dev/null 2>&1 || { echo "missing tool: $t" >&2; exit 1; }
done
command -v 7z >/dev/null 2>&1 || command -v bsdtar >/dev/null 2>&1 || { echo "missing ISO extractor (7z or bsdtar)" >&2; exit 1; }
KVM_FLAG=""
if [[ -e /dev/kvm ]]; then KVM_FLAG="-enable-kvm -cpu host"; fi
log "KVM: $([[ -n "$KVM_FLAG" ]] && echo enabled || echo 'disabled (TCG — slower)')  version=$TALOS_VERSION  workdir=$WORKDIR"

# --- 1. Talos installer ISO --------------------------------------------------
if [[ ! -f "$ISO" ]]; then
  log "downloading Talos $TALOS_VERSION metal-amd64.iso"
  curl -fsSL -o "$ISO" "https://github.com/siderolabs/talos/releases/download/${TALOS_VERSION}/metal-amd64.iso"
fi
log "using ISO: $ISO ($(du -h "$ISO" | cut -f1))"

# --- 2. Extract kernel + initrd ---------------------------------------------
if [[ ! -f "$BOOT/vmlinuz" || ! -f "$BOOT/initramfs.xz" ]]; then
  log "extracting kernel/initrd from ISO"
  rm -rf "$WORKDIR/isomnt"; mkdir -p "$WORKDIR/isomnt"
  if command -v 7z >/dev/null 2>&1; then
    7z x -y -o"$WORKDIR/isomnt" "$ISO" >/dev/null 2>&1 || die "failed to extract ISO with 7z"
  else
    bsdtar -xf "$ISO" -C "$WORKDIR/isomnt" || die "failed to extract ISO with bsdtar"
  fi
  mkdir -p "$BOOT"
  cp "$WORKDIR/isomnt/boot/vmlinuz" "$BOOT/vmlinuz"
  cp "$WORKDIR/isomnt/boot/initramfs.xz" "$BOOT/initramfs.xz"
fi

# --- 3. Blank install disk ---------------------------------------------------
if [[ ! -f "$DISK" ]]; then
  log "creating 20GB install disk"
  qemu-img create -f qcow2 "$DISK" 20G >/dev/null
fi

# --- 4. Launch VM in maintenance mode ---------------------------------------
log "launching QEMU  apid=127.0.0.1:$API_PORT  k8s=127.0.0.1:$K8S_PORT"
# shellcheck disable=SC2086
qemu-system-x86_64 $KVM_FLAG -m "$MEM_MB" -smp "$SMP" \
  -drive "file=$DISK,if=virtio,format=qcow2" \
  -kernel "$BOOT/vmlinuz" -initrd "$BOOT/initramfs.xz" \
  -append "$KERNEL_CMDLINE" \
  -netdev "user,id=n0,hostfwd=tcp::${API_PORT}-:${API_PORT},hostfwd=tcp::${K8S_PORT}-:${K8S_PORT}" \
  -device virtio-net-pci,netdev=n0 \
  -nographic -serial "file:$SERIAL" &
QEMU_PID=$!
log "qemu pid=$QEMU_PID"

# --- 5. Wait for the maintenance API to be ready ----------------------------
# NOTE: `nc` is unreliable here — QEMU user-mode (slirp) accepts the host-side
# connection eagerly, so the port "opens" seconds before apid is actually ready.
# A real gRPC call (talosctl version) is the correct readiness probe.
log "waiting for maintenance API on 127.0.0.1:$API_PORT (up to 300s)"
up=0
for i in $(seq 1 300); do
  if "$TALOSCTL" version --insecure -n 127.0.0.1 >/dev/null 2>&1; then up=1; log "apid ready after ~${i}s"; break; fi
  kill -0 "$QEMU_PID" 2>/dev/null || die "QEMU exited early"
  sleep 1
done
[[ "$up" == 1 ]] || die "maintenance API never came up"

# --- 6. Generate control-plane config ---------------------------------------
log "generating cluster config (endpoint https://$NODE_IP:$K8S_PORT, disk /dev/vda)"
"$TALOSCTL" gen config talos-home "https://$NODE_IP:$K8S_PORT" \
  --install-disk /dev/vda -o "$WORKDIR" >/dev/null
# Point the client talosconfig at the loopback-forwarded apid.
python3 - "$TALOSCONFIG" "$API_PORT" <<'PY'
import sys
path, port = sys.argv[1], sys.argv[2]
s = open(path).read()
s = s.replace("endpoints: []", "endpoints:\n            - 127.0.0.1:" + port)
open(path, "w").write(s)
PY
log "talosconfig endpoints -> 127.0.0.1:$API_PORT"

# --- 7. Apply config (installs to disk + kexec into the installed cluster) ---
# Retry-tolerant: if apid isn't fully ready the gRPC handshake fails, and it's
# safe to retry (a failed attempt applies nothing).
log "applying config (--insecure -n 127.0.0.1) — retrying until ready (up to 180s)"
applied=0
for i in $(seq 1 60); do
  if "$TALOSCTL" apply-config --insecure -n 127.0.0.1 -f "$WORKDIR/controlplane.yaml" 2>&1; then
    applied=1; log "config applied on attempt $i"; break
  fi
  kill -0 "$QEMU_PID" 2>/dev/null || die "QEMU exited during apply-config"
  sleep 3
done
[[ "$applied" == 1 ]] || { dump_serial; die "apply-config never succeeded"; }

# --- 8. Wait for the node to come up from the installed cluster --------------
# The installed cluster is ready for bootstrap once its secure API (apid) is up.
# `talosctl version -n <ip>` (secure client, from the talosconfig) is the probe:
# it fails while the installer/maintenance phase is active and succeeds once the
# installed cluster's apid is running. NOTE: do NOT use `health | grep` here —
# `talosctl health` exits non-zero while etcd is still in its join loop, and with
# `set -o pipefail` that non-zero would make the `if` false even on a match.
log "waiting for installed cluster to come up (up to 360s)..."
up=0
for i in $(seq 1 180); do
  if "$TALOSCTL" version -n 127.0.0.1 >/dev/null 2>&1; then
    up=1; log "node reachable (secure API) after ~$((i*2))s"; break
  fi
  kill -0 "$QEMU_PID" 2>/dev/null || die "QEMU exited while waiting for installed cluster"
  sleep 2
done
[[ "$up" == 1 ]] || die "installed cluster never became reachable"

# --- 9. Bootstrap the single-node etcd --------------------------------------
log "bootstrapping control plane"
"$TALOSCTL" bootstrap -n 127.0.0.1

# --- 10. Best-effort health check (etcd + apid + kubelet) --------------------
# NOTE: `talosctl health` includes an "all k8s nodes to report" sub-check that dials
# the guest IP (10.0.2.15:6443) directly. Under QEMU user-mode (slirp) NAT the host
# can only reach the guest via the loopback hostfwd (127.0.0.1:6443), so that one
# sub-check is expected to fail here and is NOT a real cluster fault. The authoritative
# readiness proof is the kubectl verification in step 12, which goes through the
# forwarded port and works. Hence this step is best-effort / informational.
log "running best-effort health check (core: etcd/apid/kubelet; k8s-node-report may fail under slirp)"
"$TALOSCTL" health -n 127.0.0.1 --wait-timeout 60s 2>&1 \
  || log "health check reported issues — proceeding to kubectl verification"

# --- 11. Grab kubeconfig and repoint to the loopback-forwarded 6443 ---------
log "fetching kubeconfig"
"$TALOSCTL" kubeconfig -n 127.0.0.1 -f "$WORKDIR/kubeconfig"
sed -i "s#server: https://$NODE_IP:$K8S_PORT#server: https://127.0.0.1:$K8S_PORT#" "$WORKDIR/kubeconfig"
export KUBECONFIG="$WORKDIR/kubeconfig"

# --- 12. Verify the control plane is Ready -----------------------------------
log "verifying with kubectl (up to 240s)"
ready=0
for i in $(seq 1 48); do
  out="$("$KUBECTL" get nodes 2>/dev/null)" || true
  # Match the STATUS column exactly ("Ready"), not a substring — `grep Ready`
  # would also match "NotReady".
  if awk 'NR>1 && $2=="Ready"{f=1} END{exit !f}' <<<"$out"; then ready=1; break; fi
  sleep 5
done
[[ "$ready" == 1 ]] || { "$KUBECTL" get nodes || true; die "no Ready node"; }

echo
"$KUBECTL" get nodes -o wide
echo
"$KUBECTL" get pods -A
echo
log "SUCCESS: single-node Talos control plane is up and Ready"
log "artifacts under $WORKDIR (kubeconfig: $WORKDIR/kubeconfig)"
