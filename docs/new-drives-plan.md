# Plan: Add 2x 4TB IronWolf Drives to ZFS Pool

## Context

Two Seagate IronWolf 4TB NAS drives (ST4000VN006) ordered from Memory Express.
Current ZFS pool `media` has ~430GB usable (sdb+sdd mirror). New drives will be
added as a second mirror vdev, expanding pool to ~4.4TB usable.

## Current pool layout

```
media         ONLINE
  mirror-0    ONLINE
    sdb        447.1G SanDisk
    sdd        465.8G Samsung 860 EVO
cache
  sda          238.5G Crucial M4 (L2ARC)
```

## Data to migrate from Drobo

| Source | Destination | Size |
|--------|-------------|------|
| `/mnt/drobo/music/` | `/media/music/` | 622GB |
| `/mnt/drobo/photos/` | `/media/immich/` | 195GB (already in progress) |
| `/mnt/drobo/movies/` | `/media/jellyfin/` | 42GB (already in progress) |

**Skip:** `data/`, `mba-15-mar-2017.dmg`, `mbp-4-mar-2012.dmg`,
`mbp-4-mar-2012.dmg.sparseimage`, `photos.zip`, `itunes 2017` (overlaps music)

---

## Step 1: Install drives

1. Power off home-server
2. Install both 4TB drives in free bays
3. Connect SATA data + power cables
4. Power on, SSH in

## Step 2: Identify new drives

```bash
lsblk -d -o NAME,SIZE,MODEL
```

Note the device names of the two new 4TB drives (e.g. `sde`, `sdf`).
Confirm they show as ~3.6TB and model matches IronWolf.

## Step 3: Add as new mirror vdev to ZFS pool

```bash
# Replace sde and sdf with actual device names from Step 2
sudo zpool add media mirror /dev/sde /dev/sdf
```

Verify pool layout:
```bash
sudo zpool status media
```

Expected output shows `mirror-0` (existing) and `mirror-1` (new) both ONLINE.

## Step 4: Confirm pool capacity

```bash
zfs list media
```

Should show ~4.4TB available.

## Step 5: Copy music from Drobo

First confirm Drobo is still mounted:
```bash
ls /mnt/drobo/music | head -5
# If not mounted:
sudo mount -t hfsplus -o ro /dev/sde2 /mnt/drobo
```

Start music copy:
```bash
tmux new-window -t copy -n music
# In that window:
rsync -a --exclude=".*" --info=progress2 /mnt/drobo/music/ /media/music/
```

This will take several hours (622GB). Monitor with:
```bash
watch -n30 "zfs list -r media"
```

## Step 6: Verify copies completed

```bash
# Check all three completed without errors
wc -l /tmp/copy-movies.log
wc -l /tmp/copy-photos.log
grep -i error /tmp/copy-movies.log
grep -i error /tmp/copy-photos.log

# Spot check file counts
find /media/jellyfin -type f | wc -l
find /media/immich -type f | wc -l
find /media/music -type f | wc -l
```

## Step 7: Fix ownership for services

```bash
sudo chown -R jellyfin:jellyfin /media/jellyfin
sudo chown -R jellyfin:jellyfin /media/immich
# music stays as todd until Navidrome ownership is confirmed
```

## Step 8: Configure Jellyfin library

1. Open `http://10.0.0.8:8096`
2. Complete setup wizard if not done
3. Add media library → Movies → `/media/jellyfin`
4. Run library scan

## Step 9: Navidrome will auto-scan music

Navidrome polls `/media/music` automatically. Once music is copied it will
begin indexing. Check progress at `http://10.0.0.8:4533`.

## Step 10: Set up Immich

Immich requires Docker. Steps deferred until photos copy is complete and
verified. See separate plan (to be written).

## Step 11: Unmount and disconnect Drobo

Once all copies verified:
```bash
sudo umount /mnt/drobo
```

Power off Drobo. Keep it as cold backup until confident all data is safe on ZFS.

## Step 12: Update nameservers comment in config

Remove the stale comment from `hosts/home-server/configuration.nix` and
commit any outstanding changes.

---

## Useful monitoring commands

```bash
# ZFS pool status
sudo zpool status media
zfs list -r media

# Copy progress (if rsync still running)
ssh todd@10.0.0.8 'tmux attach -t copy'

# Service status
ssh todd@10.0.0.8 'systemctl is-active jellyfin navidrome adguardhome'

# Disk usage
ssh todd@10.0.0.8 'df -h /media/*'
```
