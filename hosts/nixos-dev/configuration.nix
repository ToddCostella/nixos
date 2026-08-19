# NixOS Configuration for nixos-dev (Dell XPS laptop)
# Physical-machine-specific settings only. The desktop environment, dev tooling,
# 1Password, fonts, package set, and DE specialisations live in the shared
# ./desktop-tools.nix (also imported by hosts/vm-guest). Base config that both
# machines share is in modules/common.nix.
{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./desktop-tools.nix
  ];

  # Boot loader configuration
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  boot.loader.systemd-boot.consoleMode = "1";  # Lower resolution for readable text on high-DPI displays

  # Enable nested virtualization and VM optimizations
  boot.extraModprobeConfig = ''
    options kvm_intel nested=1
    options kvm_intel emulate_invalid_guest_state=0
    options kvm ignore_msrs=1
  '';

  # Enable IOMMU for better device passthrough support
  # usbcore.autosuspend=-1 fixes USB controller resume issues after suspend
  boot.kernelParams = [ "intel_iommu=on" "iommu=pt" "usbcore.autosuspend=-1" "hugepagesz=2M" ];

  # Networking
  networking.hostName = "nixos-dev";
  networking.nameservers = [ "10.0.0.8" "1.1.1.1" ];  # AdGuard Home, Cloudflare fallback
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [
      networkmanager-openvpn  # For NordVPN OpenVPN connections
    ];
  };

  # Filesystem mounts
  # Internal backup drive (WD_BLACK SN770 1TB, nvme0n1) — repurposed from the
  # former Debian dual-boot install. Single ext4 partition (label: backup-internal)
  # holding the local Pika/Borg backup repo. `nofail` so a missing/unformatted
  # drive never blocks boot.
  fileSystems."/mnt/backup-internal" = {
    device = "/dev/disk/by-label/backup-internal";
    fsType = "ext4";
    options = [ "defaults" "nofail" ];
  };

  # QEMU/KVM virtualization for Windows 11 with enhanced stability
  virtualisation.libvirtd = {
    enable = true;
    qemu = {
      package = pkgs.qemu_kvm;
      runAsRoot = false;
      swtpm.enable = true;
    };
    onBoot = "ignore";
    onShutdown = "shutdown";
    parallelShutdown = 10;
  };

  # Hugepages for Windows VM (16GB = 8192 x 2MB pages)
  # Only allocated on-demand by libvirt when VM starts
  boot.kernel.sysctl."vm.nr_hugepages" = 8192;

  # CPU power management (intel_pstate).
  # power-profiles-daemon (enabled by GNOME by default) overrides intel_pstate EPP
  # and was silently pinning all cores to 900 MHz, so it stays disabled.
  #
  # On intel_pstate, "powersave" is the normal *dynamic* governor — it scales
  # frequency to load, not a fixed low clock. The old "performance" governor held
  # every core near its max (~4.5 GHz) even at idle, running the package at ~83°C
  # and keeping the fans on constantly. "powersave" + balance_performance EPP lets
  # idle cores drop to 800 MHz (idle package ~38°C) while still boosting on demand.
  services.power-profiles-daemon.enable = false;
  powerManagement.cpuFreqGovernor = "powersave";
  # intel_pstate energy/performance bias — balanced, favouring performance.
  systemd.services.set-cpu-epp = {
    description = "Set intel_pstate energy_performance_preference";
    wantedBy = [ "multi-user.target" ];
    after = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Guard for hardware without intel_pstate EPP (VMs, non-Intel CPUs): if no
      # EPP sysfs paths exist, skip cleanly instead of failing the unit. `nullglob`
      # makes the glob expand to nothing when there are no matches.
      ExecStart = "${pkgs.bash}/bin/bash -c 'shopt -s nullglob; for e in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do echo balance_performance > \"$e\"; done'";
    };
  };

  # Intel thermal daemon — proactive thermal management on this laptop.
  services.thermald.enable = true;

  # Fix Dell XPS touchscreen not working after suspend/resume
  systemd.services.fix-touchscreen-resume = {
    description = "Reload i2c-hid after resume to fix touchscreen";
    after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    wantedBy = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.kmod}/bin/modprobe -r i2c_hid_acpi";
      ExecStartPost = "${pkgs.kmod}/bin/modprobe i2c_hid_acpi";
    };
  };

  # Full user group list for laptop (overrides common.nix extraGroups)
  users.users.todd.extraGroups = [ "networkmanager" "wheel" "docker" "dialout" "libvirtd" ];

  # Enable Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # fwupd - Firmware update daemon for Dell and other hardware
  services.fwupd.enable = true;

  system.stateVersion = "24.05";
}
