#!/usr/bin/env bash
#
# Provision the persistent `vm-guest` libvirt VM and boot it off the NixOS
# installer ISO. After it boots, follow docs/vm-guest-install.md to partition
# and install the flake config.
#
# Idempotent-ish: refuses to clobber an existing `vm-guest` domain — destroy it
# yourself first (see bottom) if you want to start over.

set -euo pipefail

VM_NAME="vm-guest"
RAM_MB=8192
VCPUS=4
DISK_GB=60
DISK_PATH="/var/lib/libvirt/images/${VM_NAME}.qcow2"
ISO_PATH="${HOME}/Downloads/nixos-minimal-vm-guest.iso"
URI="qemu:///system"

command -v virt-install >/dev/null || { echo "virt-install not found" >&2; exit 1; }
[ -f "$ISO_PATH" ] || { echo "ISO not found at $ISO_PATH — download it first" >&2; exit 1; }

# Guard: don't overwrite an existing domain.
if virsh -c "$URI" dominfo "$VM_NAME" >/dev/null 2>&1; then
  echo "A domain named '$VM_NAME' already exists." >&2
  echo "To recreate it, first run:" >&2
  echo "  virsh -c $URI destroy $VM_NAME 2>/dev/null; virsh -c $URI undefine $VM_NAME --nvram --remove-all-storage" >&2
  exit 1
fi

echo "Creating $VM_NAME: ${VCPUS} vCPU, ${RAM_MB} MB RAM, ${DISK_GB} GB disk, UEFI, virtio, SPICE."

# --boot uefi selects OVMF (matches the working win11 VM's firmware).
# virtio disk + net for performance; qxl + spice for a usable graphical console
# with clipboard sharing (the guest runs spice-vdagentd via the flake config).
sudo virt-install \
  --connect "$URI" \
  --name "$VM_NAME" \
  --memory "$RAM_MB" \
  --vcpus "$VCPUS" \
  --cpu host-passthrough \
  --boot uefi \
  --disk "path=${DISK_PATH},size=${DISK_GB},bus=virtio,format=qcow2" \
  --cdrom "$ISO_PATH" \
  --osinfo nixos-25.11 \
  --network network=default,model=virtio \
  --graphics spice \
  --video qxl \
  --channel spicevmc \
  --noautoconsole

echo ""
echo "VM '$VM_NAME' created and booting the installer ISO."
echo "Open the console with:"
echo "  virt-viewer --connect $URI $VM_NAME"
echo "  # or: virt-manager"
echo ""
echo "Then follow docs/vm-guest-install.md (partition -> generate hw config -> nixos-install)."
