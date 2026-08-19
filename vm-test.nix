# VM-only test overlay — NOT imported by any real host.
# Layered on top of nixos-dev to make the throwaway QEMU VM usable: gives `todd`
# a known password and auto-logs into GNOME, since the real config sets no
# password (you run `passwd` post-install on hardware).
#
# Usage:
#   nixos-rebuild build-vm --flake .#vm-test
#   rm -f nixos-dev.qcow2          # discard any prior VM disk for a clean boot
#   ./result/bin/run-nixos-dev-vm  # RAM/cores/graphics are baked in (below)
#   (auto-logs into GNOME as todd; password is `test` if ever prompted)
#
# Notes:
#   - build-vm auto-generates the VM root disk, so the real disk UUIDs in
#     hardware-configuration.nix are ignored.
#   - /mnt/backup-internal already has `nofail`, so its missing device does not
#     block boot — no override needed here.
#   - The real config reserves 16 GB of hugepages for nested KVM; that starves a
#     smaller VM and OOM-kills services, so it is zeroed out below.
#
# This overlay is referenced only by the `vm-test` flake output, never by a real
# host. Safe to delete (and remove that flake output) anytime.
{ lib, ... }:
{
  # Known throwaway credentials for the test VM only.
  users.users.todd.initialPassword = lib.mkForce "test";
  users.users.root.initialPassword = lib.mkForce "test";

  # Skip the GDM password prompt so the VM lands straight in GNOME.
  services.displayManager.autoLogin = {
    enable = true;
    user = "todd";
  };

  # Bake VM resources into the generated runner so they don't depend on
  # QEMU_OPTS being exported correctly. GNOME + Docker + libvirtd OOM'd at the
  # default 1 GB; give the VM real headroom.
  virtualisation.vmVariant.virtualisation = {
    memorySize = 8192;   # MiB
    cores = 4;
    diskSize = 16384;    # MiB — writable /nix/store overlay + user space
    # QXL/virtio graphics for a usable GNOME session.
    qemu.options = [ "-vga qxl" ];
  };

  # The real config reserves 16 GB of hugepages (vm.nr_hugepages = 8192 * 2 MB)
  # to back nested-KVM guests on the physical host. Inside this VM there are no
  # nested guests, and reserving 16 GB from 8 GB of RAM starves everything and
  # OOM-kills nix-daemon/services. Zero it out and drop the hugepage kernel param
  # for the test VM only. (The physical host keeps its hugepages.)
  boot.kernel.sysctl."vm.nr_hugepages" = lib.mkForce 0;
  boot.kernelParams = lib.mkForce [ "intel_iommu=on" "iommu=pt" "usbcore.autosuspend=-1" ];
}
