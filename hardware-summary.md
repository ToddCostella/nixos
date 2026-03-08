# Hardware Summary

Generated: 2026-03-05

---

## nixos-dev (Dell XPS 15 Laptop)

### CPU
- **Model**: Intel Core i7-10875H @ 2.30GHz (Comet Lake-H, 2020)
- **Cores/Threads**: 8 cores / 16 threads
- **Max Turbo**: 5.1 GHz
- **Virtualization**: VT-x enabled

### Memory
- **Total**: 64 GB RAM
- **In Use**: ~14 GB used, ~47 GB available
- **Swap**: 68 GB (NVMe-backed)

### Storage

| Device | Model | Size | Role |
|--------|-------|------|------|
| `nvme0n1` | WD Black SN750 2TB | 1.8 TB | Primary (NixOS `/boot`, Debian `/mnt/debian`, swap) |
| `nvme1n1` | WD Black SN770 1TB | 931.5 GB | Secondary (NixOS root `/`) |

### GPU
- **Integrated**: Intel UHD Graphics 630 (`8086:9bc4`) — driver: i915
- **Discrete**: NVIDIA GeForce RTX 2060 (`10de:1f12`) — driver: nouveau

### Network
- **WiFi**: Intel Wi-Fi 6 AX201 (`wlp0s20f3`) — `10.0.0.21/24`
- Docker bridge interfaces active (`172.17.0.0/16`, `172.18.0.0/16`, `172.19.0.0/16`)

### Power
- **Battery**: DELL F8CPG4C — Status: Full (100%)

### OS
- **NixOS 26.05** (Yarara), kernel 6.18.10

### Running Services
- Display manager (GDM/GNOME), Bluetooth, CUPS printing
- Docker, Nix daemon
- Avahi (mDNS), NetworkManager, WPA Supplicant
- SSH, fwupd, ModemManager, Thunderbolt (bolt)
- PipeWire/audio, power-profiles-daemon, udisks2

---

## home-server (Headless Mini PC)

### CPU
- **Model**: Intel Core i7-4790K @ 4.00GHz (Haswell, 2014)
- **Cores/Threads**: 4 cores / 8 threads
- **Max Turbo**: 4.4 GHz
- **Virtualization**: VT-x enabled

### Memory
- **Total**: 32 GB RAM
- **In Use**: ~28 GB (services + ZFS ARC cache)
- **Swap**: None configured

### Storage

| Device | Model | Size | Role |
|--------|-------|------|------|
| `sda` | Crucial M4 SSD 256GB | 238.5 GB | ZFS L2ARC cache |
| `sdb` | SanDisk Ultra II 480GB | 447.1 GB | ZFS `media` pool (mirror leg) |
| `sdc` | Samsung 860 EVO 500GB | 465.8 GB | OS boot disk (`/boot` + `/`) |
| `sdd` | Samsung 860 EVO 500GB | 465.8 GB | ZFS `media` pool (mirror leg) |

**ZFS Pool `media`**: 444 GB mirror (sdb + sdd), 232 GB used (52%), L2ARC on sda. ONLINE, no errors.

### GPU
- None detected (headless)

### Network
- **NIC**: Intel I218-LM onboard Ethernet (`eno1`) — `10.0.0.8/24`

### OS
- **NixOS 26.05** (Yarara), kernel 6.18.10

### Running Services
- AdGuard Home (DNS ad-blocking)
- Jellyfin (media server)
- Navidrome (music server)
- ZFS Event Daemon (zed)
- SSH, Avahi (mDNS), NetworkManager
