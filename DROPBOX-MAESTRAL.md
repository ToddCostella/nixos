# Dropbox on NixOS — via Maestral

**TL;DR:** Dropbox syncs through **[Maestral](https://maestral.app/)** (an open-source
Dropbox client), *not* the official `dropbox` package. Maestral runs as a systemd
user service on `nixos-dev`, syncing `~/Dropbox` (~748 GB). Config lives in
`home/todd-desktop.nix`.

---

## Why Maestral instead of the official Dropbox client

The official nixpkgs `dropbox` package **could not complete syncing on this
GNOME/Wayland setup**. After extensive debugging, the failure was fundamental,
not a config mistake:

- The package runs the proprietary daemon inside a **bwrap FHS sandbox**.
- From inside that sandbox it **cannot open a browser** to show the device-link
  page, and it emits **no link URL** to stdout, the journal, or any captured
  output — so the interactive link flow never surfaces (not via the service,
  a terminal, the app launcher, or a fresh state).
- Even after linking succeeded *server-side* (confirmed on dropbox.com — the
  device showed as linked), the local daemon **kept rewriting `unlink.db`**,
  **never armed inotify watches**, and never reached a synced state. It would
  spin at high CPU indefinitely without converging.

Maestral solves all of this: it runs **unsandboxed**, links via an **auth code
pasted into the terminal** (no browser-launch dependency), and is designed for
**headless / systemd** operation. It linked and began syncing on the first try.

## Why the original setup broke (root cause)

The original problem was reported as "Dropbox isn't syncing my local files."
Two stacked issues:

1. **No autostart.** The official daemon had only ever been launched by hand, so
   a reboot left it dead and nothing restarted it. (First fix attempt: a systemd
   user service — correct idea, wrong client.)
2. **A migration scrambled the link state.** An attempt to adopt the upstream
   `services.dropbox` HM module (which remaps `HOME` to `~/.dropbox-hm` and
   symlinks the canonical paths) deleted `info.json`/`host.db` and left the local
   Dropbox database in a state the daemon refused to accept — it kept insisting
   it was unlinked. This is what ultimately forced the switch to Maestral.

Throughout all of this, the **748 GB of files in `~/Dropbox` were never touched**
— `~/Dropbox` is a plain directory, independent of the daemon's state dir.

---

## Current setup (declarative)

Defined in `home/todd-desktop.nix`:

- `maestral` in `home.packages`
- `systemd.user.services.maestral` runs `maestral start -f` (foreground), so
  systemd supervises it directly. Starts on login (`WantedBy=default.target`),
  restarts on failure.

The **link credentials and sync config are NOT declarative** — Maestral stores
them in `~/.config/maestral/` and the system keyring after a one-time
interactive `maestral auth link` (see below). This is analogous to the Proton
Bridge keyring login: HM can't inject it.

## First-time setup (one-time, interactive)

Run in a terminal (the auth + first-run need a TTY):

```bash
# 1. Link the account — prints an auth URL, then prompts for a code
maestral auth link
#    -> choose "Open Dropbox website", authorize, paste the code back
#    -> "✓ Linked to toddcostella@gmail.com"

# 2. Point it at the EXISTING folder (so it matches local files, no re-download)
maestral config set path ~/Dropbox

# 3. First run must be interactive (the service can't do the initial setup —
#    it needs a TTY or throws termios "Inappropriate ioctl for device")
maestral start

# 4. Once "maestral status" shows syncing/up-to-date, hand off to the service:
maestral stop
systemctl --user start maestral.service
```

## Day-to-day commands

```bash
maestral status          # sync state: "Up to date" / "Syncing ↓ N/M" / errors
maestral status ~/Dropbox/somefile   # per-file status
maestral pause / resume  # pause or resume syncing
maestral excluded list   # selective-sync exclusions
systemctl --user status maestral.service
journalctl --user -u maestral.service -f
```

## Gotchas

- **First run needs a TTY.** `maestral start` under systemd on a never-set-up
  config throws `termios.error: Inappropriate ioctl for device` because it tries
  to show an interactive setup prompt. Do the first `maestral start` in a
  terminal, then hand off to the service.
- **`maestral status` starts as "Paused"** right after linking — it syncs once
  the daemon is properly started (via `maestral start`, not just linking).
- **Existing 748 GB folder:** Maestral indexes and matches local files against
  the server by hash — it does **not** re-download everything. The initial
  reconcile of a folder this large takes a while (watch `maestral status`);
  0 sync errors + a stable folder size = healthy.
- **Leftover state from the old official client** can be removed once Maestral is
  confirmed working: `~/.dropbox`, `~/.dropbox-dist`, `~/.dropbox-hm`,
  `~/.dropbox-corrupted-bak`. (Never touch `~/Dropbox` itself.)
