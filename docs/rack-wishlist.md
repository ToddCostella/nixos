# Home Lab Rack & Networking Wishlist

## Goal

Consolidate home-server hardware and networking gear into a clean rack setup.
Take ownership of firewall, switching, and WiFi — replacing Rogers-controlled equipment.

## Current Situation

- **home-server**: Gigabyte GA-Z97X-UD3H-BK (full ATX), i7-4790K, 32GB RAM — in a large tower case
- **ISP gateway**: Rogers/Shaw CGM4331COM (Technicolor) — rented, combined modem+router+WiFi
  - Supports IP Passthrough mode (effectively dumb modem) — request from Rogers support
  - Bridge Mode availability inconsistent on this model — IP Passthrough is the safer ask
- **Switch**: TP-Link (10.0.0.92) — current unmanaged/lightly managed unit
- **WiFi**: Integrated in Rogers gateway — to be replaced

## Proposed Rack Stack (9U freestanding with wheels)

| U | Device | Purpose | Est. Cost (CAD) |
|---|--------|---------|----------------|
| 1U | Protectli Vault Pro VP2420 | Fanless firewall, Intel J6412, 4x 2.5GbE, 8GB RAM, 120GB SSD, AES-NI, runs OPNsense — [Amazon.ca](https://www.amazon.ca/Protectli-Vault-VP2420-4-Firewall-Appliance/dp/B0BQ1K182Y/) | ~$450 |
| 1U | TP-Link TL-SG2218 | 16-port Gigabit smart switch, 2x SFP, Omada SDN — [Amazon.ca](https://www.amazon.ca/TP-Link-JetStream-16-Port-Gigabit-TL-SG2218/dp/B093Y2S3PB/) | ~$180 |
| 1U | PDU power strip | Included with RIVECO rack | — |
| 1U | Rack shelf | Included with RIVECO rack | — |
| 4U | Rosewill RSV-R4000U | ATX rackmount chassis, 8x 3.5" + 3x 5.25" bays, 4x fans included — [Amazon.ca](https://www.amazon.ca/Rosewill-Chassis-Rackmount-Computer-RSV-R4000U/dp/B09HLCNKM3/) | ~$130 |
| 1U | Free | — | — |
| — | Rack rails for RSV-R4000U | Sliding rails (if not included) | ~$40 |
| — | RIVECO 9U Open Frame Rack with Wheels | 4-post 19", casters, includes 1U shelf + PDU — [Amazon.ca](https://www.amazon.ca/Server-Rack-Open-Frame-Casters/dp/B0BLCLPXWR/) | ~$180–220 |

**Estimated total: ~$1,000–1,040 CAD** (excluding cables; PDU + shelf included with rack)

### Server hardware (existing, no cost)
- Gigabyte GA-Z97X-UD3H-BK (ATX) — fits RSV-R4000U directly
- Corsair RM650i PSU (standard ATX, fully modular) — fits RSV-R4000U rear bay, 650W well within headroom
- i7-4790K, 32GB RAM, 2x IronWolf 4TB, 2x Samsung 860 EVO, Crucial M4

### EAP670 placement
- TP-Link Omada EAP670, WiFi 6 AX5400, 2.5G, PoE+ powered — [Amazon.ca](https://www.amazon.ca/TP-Link-Business-AX5400-Ceiling-EAP670/dp/B0CRLYWHBL/)
- Ceiling or wall mounted in the room — not racked
- PoE+ powered — needs PoE+ capable switch port or included power adapter (TL-SG2218 has no PoE)
- Managed via Omada SDN controller alongside existing AX1800 outdoor AP

### Software (all free, self-hosted on home-server)
- **OPNsense** — firewall/router OS on Protectli VP2420
- **Omada SDN Controller** — Docker container on home-server, manages EAP670 + existing AX1800 outdoor AP + TL-SG2210MP switch

### Notes on firewall choice
- **OPNsense** preferred over pfSense — more actively developed, cleaner UI, built-in mDNS reflector
- Protectli VP2420: fanless, passive cooling, fits 1U, good OPNsense support

### Notes on WiFi choice
- **TP-Link EAP670** chosen — existing TP-Link EAP AX1800 outdoor unit already in use
- All APs managed together via **Omada SDN controller** (Docker container on home-server)
- TL-SG2218 switch is also Omada-managed — single controller UI for switch + all APs
- TL-SG2218 has no PoE — EAP670 and AX1800 use included power adapters

## Server

Keeping existing hardware — GA-Z97X-UD3H-BK (ATX), i7-4790K, 32GB RAM. Still
capable for DNS, media serving, and ZFS. Server stays in its current tower case
positioned near the rack, with clean cable runs to the switch.

## Proposed VLANs

| VLAN | Name | Devices |
|------|------|---------|
| 10 | Trusted | nixos-dev, home-server, Raspberry Pi (GloomTable) |
| 20 | IoT | Sonos x2, Epson ET-3700 printer, Apple TV |
| 30 | Mobile / Guest | iPads, iPhones |

OPNsense handles inter-VLAN routing + firewall rules. Built-in mDNS reflector
resolves Bonjour/AirPlay across VLANs (Sonos, AirPrint).

## Open Questions

- [x] ~~Wall-mount or freestanding rack?~~ Freestanding with wheels
- [x] ~~How many wired ports?~~ 8-port switch sufficient — all wired devices in one room
- [x] ~~Option A (keep ATX board) or Option B (mini-ITX rebuild)?~~ Keeping existing hardware
- [ ] Single AP sufficient or planning multi-room coverage?
- [ ] Confirm Rogers set-top box behaviour before enabling IP Passthrough on CGM4331
  - Set-top boxes use MoCA/Rogers proprietary WiFi via the gateway directly
  - IP Passthrough should not affect them but worth verifying with Rogers support first

## Wired Devices (office room)

| Device | Connection |
|--------|------------|
| home-server | Ethernet to switch |
| nixos-dev (laptop) | Ethernet to switch (when docked) |
| Raspberry Pi (GloomTable) | Ethernet to switch |
| Epson ET-3700 printer | Ethernet to switch |
| Firewall WAN | Ethernet to Rogers CGM4331 LAN port |
| Firewall LAN | Ethernet to switch uplink |

Remaining switch ports: ~2 spare

## Wireless Devices

| Device | VLAN (planned) |
|--------|---------------|
| nixos-dev (WiFi) | VLAN 10 Trusted |
| Todd's iPad x2 | VLAN 30 Mobile |
| iPhones | VLAN 30 Mobile |
| Sonos x2 | VLAN 20 IoT |
| Apple TV | VLAN 20 IoT |
| Rogers set-top boxes | Rogers gateway (independent of this network) |
