# Home Network Diagram

Generated: 2026-03-05 | Subnet: 10.0.0.0/24

```mermaid
graph TD
    Internet(["🌐 Internet"])
    Router["📡 Xfinity Router / Gateway\n10.0.0.1\nMAC: 48:4b:d4:6b:db:93\ndnsmasq 2.83 · HTTP/HTTPS · UPnP"]

    Internet --> Router

    subgraph LAN ["Local Network — 10.0.0.0/24"]

        subgraph Servers ["Servers"]
            HomeServer["🖥️ home-server\n10.0.0.8\nNixOS 26.05 · i7-4790K · 32GB\nSSH :22 · DNS/Unbound :53\nAdGuard Home · Jellyfin\nNavidrome · ZFS media pool"]
            GloomTable["🎲 GloomTable (Raspberry Pi)\n10.0.0.130\nGloomhaven tabletop companion\nDebian 12 · FastAPI/Uvicorn :8080 · SSH :22\nMAC: 2c:cf:67:7e:3c:f8 (RPi Trading Ltd)"]
        end

        subgraph Workstations ["Workstations"]
            NixosDev["💻 nixos-dev\n10.0.0.21\nNixOS 26.05 · i7-10875H · 64GB\nWiFi · Docker"]
        end

        subgraph Network ["Network Infrastructure"]
            TPLink["🔀 TP-Link Switch / AP\n10.0.0.92\nTP-LINK HTTPD · HTTP/HTTPS\nMAC: 40:ed:00:ba:90:ac"]
        end

        subgraph Mobile ["Mobile Devices"]
            iPad["📱 Todd's iPad\n10.0.0.210\nApple iPad (mDNS confirmed)\nMAC: c6:c6:ba (randomized)"]
            AppleDevice1["📱 Apple Device\n10.0.0.100\nRandomized MAC: 32:da:61\nports 49152 / 62078"]
            AppleSleeping["📱 Apple Device (sleeping)\n10.0.0.80\nMAC: b0:a7:32:ee:95:98\nNo open ports"]
        end

        subgraph Media ["Media / Smart Home"]
            AppleTV["📺 Apple TV / AirPlay\n10.0.0.50\nRTSP :554 · DNS :53\nMAC: 04:17:b6:f0:0a:37"]
            Sonos1["🔊 Sonos Speaker\n10.0.0.205\nport 6668\nMAC: 40:f5:20:e8:41:c9"]
            Sonos2["🔊 Sonos Speaker\n10.0.0.211\nport 6668\nMAC: 10:d5:61:67:f5:05"]
            Unknown["📱 Apple Device (iPhone/iPad)\n10.0.0.244\nports 49152 / 62078 (Apple lockdown)\nRandomized MAC: 1a:87:4a:29:d3:06"]
        end

        subgraph Peripherals ["Peripherals"]
            Printer["🖨️ Epson ET-3700\n10.0.0.221\nIPP/IPPS :631 · JetDirect :9100\nAirPrint · Scan · Duplex · Color\nMAC: f8:d0:27:36:71:47"]
        end

        subgraph Docker ["Docker (on nixos-dev) — 172.x.0.0/16"]
            DockerBridge1["🐳 Container net: 172.18.0.0/16\n2 containers active"]
            DockerBridge2["🐳 Container net: 172.19.0.0/16\n2 containers active"]
        end

    end

    Router --> HomeServer
    Router --> GloomTable
    Router --> NixosDev
    Router --> TPLink
    Router --> iPad
    Router --> AppleDevice1
    Router --> AppleSleeping
    Router --> AppleTV
    Router --> Sonos1
    Router --> Sonos2
    Router --> Unknown
    Router --> Printer

    NixosDev --> DockerBridge1
    NixosDev --> DockerBridge2

    HomeServer -- "DNS :53" --> NixosDev
    HomeServer -- "DNS :53" --> iPad
    HomeServer -- "DNS :53" --> LinuxServer
```

## Device Inventory

| IP | Hostname | Type | Identification Method |
|----|----------|------|-----------------------|
| 10.0.0.1 | gateway | Xfinity router | HTTP banner: "Xfinity Broadband Router Server"; dnsmasq |
| 10.0.0.8 | home-server | NixOS server | SSH, confirmed |
| 10.0.0.21 | nixos-dev | NixOS laptop | Local host |
| 10.0.0.50 | — | Apple TV / AirPlay device | RTSP :554, Apple OUI (04:17:b6) |
| 10.0.0.80 | — | Apple device (sleeping) | Apple OUI (b0:a7:32), no open ports |
| 10.0.0.92 | — | TP-Link switch/AP | HTTP banner: "TP-LINK HTTPD/1.0" |
| 10.0.0.100 | — | Apple mobile device | Ports 49152/62078 (Apple lockdown), randomized MAC |
| 10.0.0.130 | GloomTable | Raspberry Pi — Gloomhaven tabletop companion | HTTP title "GloomTable", FastAPI/Uvicorn :8080, OpenSSH 9.2p1 Debian 12, OUI: RPi Trading Ltd |
| 10.0.0.205 | — | Sonos speaker | Port 6668 (Sonos protocol) |
| 10.0.0.210 | Todds-iPad | Apple iPad | mDNS: `Todds-iPad.local`, companion-link service |
| 10.0.0.211 | — | Sonos speaker | Port 6668 (Sonos protocol) |
| 10.0.0.221 | EPSON367147 | Epson ET-3700 printer | mDNS confirmed, IPP/AirPrint |
| 10.0.0.244 | — | Apple iPhone/iPad | Ports 49152/62078 (Apple lockdown), randomized MAC |
