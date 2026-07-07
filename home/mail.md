# Mail setup runbook (Proton Bridge + mbsync + notmuch + aerc)

Operational notes for the decoupled Maildir email stack defined in
[`mail.nix`](./mail.nix). Read that file's header for the *why*; this file is
the *how* — day-to-day commands and the gotchas that cost real time.

nixos-dev only. The whole stack depends on Proton Bridge, which runs only on
this host.

## Data flow

```
Proton servers
   │  (Bridge's account sync, upstream over HTTPS)
   ▼
Proton Mail Bridge          systemd user service, 127.0.0.1:1143 IMAP / :1025 SMTP
   │  (mbsync, every 5 min, STARTTLS)
   ▼
~/Mail/proton/              LOCAL MAILDIR CACHE — a mirror, NOT the source of truth
   ├── Inbox/  Archive/  Sent/  Drafts/  Spam/  Trash/  Starred/
   ├── Folders/…  Labels/…      (custom Proton folders + kept labels)
   └── each is Maildir: cur/ new/ tmp/ + .mbsyncstate
   │  (notmuch new, after each sync)
   ▼
~/Mail/.notmuch/            search index
   │
   ▼
aerc                        reads the notmuch backend (offline, fast)
msmtp                       sends via Bridge :1025
```

`~/Mail/proton/` is a **synced cache**. The authoritative copy lives on Proton.
Deleting the cache is safe — a fresh mbsync repopulates it — but a full cold
re-sync is slow and can hit the bulk-op stall below, so avoid it casually.

## Key facts

- IMAP: `127.0.0.1:1143`, STARTTLS, user `toddcostella@protonmail.com`.
- Bridge password: **not** the Proton login. Bridge-specific, stored in
  1Password, injected to `~/.secrets.env` as `PROTON_BRIDGE_PASS` by
  `refresh-secrets`. mbsync/msmtp/the archive service all read it from there.
- Bridge's TLS cert is self-signed; exported once to
  `~/.config/protonmail/bridge.pem` (see `home.activation.exportBridgeCert`).

## The three config decisions (and why)

1. **`Remove Far`** (`accounts.email.accounts.proton.mbsync.remove = "imap"`).
   Propagates local deletions UP to Proton, so deleting mail in aerc removes it
   from the web client too. `Remove None` (the old default) made local deletes
   cosmetic — the original bug. Deliberately NOT `both`: a vanished remote label
   must never delete local mail.
   - Caveat: a deleted message still remains in Proton's **All Mail** (Proton
     always keeps a copy there). Only emptying Trash truly erases it.

2. **flock overlap guard** on `mbsync.service` `ExecStart`. A full sync can
   exceed the 5-min timer; without the guard, two runs deadlock on the
   `.mbsyncstate` lock. `flock -n` makes a second run skip instead. The
   `mail-archive` service shares the same lock so an archive and a sync can
   never hit Bridge at once.

3. **`!All Mail` in Patterns.** All Mail is a redundant superset (~82k msgs) —
   every message already syncs via another folder. Worse, a cold reconcile
   makes mbsync issue one `UID FETCH 1:<82k> (FLAGS)`, which Bridge chokes on.
   Excluding it removed the stall and ~7.5 GB of local disk.

## ⚠️ Bridge chokes on large bulk IMAP operations

The single most important gotcha. Bridge (its gluon IMAP engine) stalls on big
batched commands — seen with the 82k All Mail FETCH and a 552-message Trash
EXPUNGE. Symptoms: the client hangs, `ss` shows MBs stuck in the socket
Send-Q, and Bridge logs `broken pipe` / `connection reset` / repeated
`Failed to send progress message`.

Rules:
- **Chunk bulk operations.** `archive_old_inbox.py` moves in batches of 50 for
  this reason. Don't raise it.
- **The operation often DID happen server-side** even when the client hangs —
  Bridge just fails to send the completion response and retries against the dead
  client. Verify actual state after, don't assume it failed.
- **Recovery from a stuck Bridge session:**
  ```sh
  systemctl --user restart protonmail-bridge.service
  ```
  Clears stuck sessions. Wait ~6s for :1143 to relisten, then a few more for it
  to reconnect upstream before IMAP logins succeed.

Also seen: transient `no route to host` to Proton (185.70.42.x) — a network
blip, not our config. Bridge recovers on its own once connectivity returns; a
sync that connected mid-blip may wedge and need the restart above.

## Routine operations

### Automatic
- **mbsync.timer** — every 5 min, syncs all folders except All Mail.
- **mail-archive.timer** — weekly (Mon 03:00), moves INBOX mail >3 months to
  Archive. Both are declarative in `mail.nix`.

### Manual: archive old inbox mail
`archive_old_inbox.py` (in this repo; also runs as the mail-archive service).
```sh
export PROTON_BRIDGE_USER=toddcostella@protonmail.com   # PROTON_BRIDGE_PASS from ~/.secrets.env
python3 ~/nixos-config/home/archive_old_inbox.py            # DRY RUN (default) — reports only
python3 ~/nixos-config/home/archive_old_inbox.py --apply    # actually move
python3 ~/nixos-config/home/archive_old_inbox.py --months 6 --apply
```
Or trigger the service: `systemctl --user start mail-archive.service`.

### Manual: empty Spam / Trash
`empty_spam_trash.py` (in this repo).
```sh
export PROTON_BRIDGE_USER=toddcostella@protonmail.com
python3 ~/nixos-config/home/empty_spam_trash.py --report   # counts only
python3 ~/nixos-config/home/empty_spam_trash.py            # mark \Deleted + EXPUNGE both
```
Large Trash may stall (see bulk-op gotcha) — the delete usually still lands;
restart Bridge and re-check counts.

## Health checks / troubleshooting

```sh
# Did the timer succeed unattended?
journalctl --user -u mbsync.service --since '-1 day' | grep -E 'Starting|Finished|Failed|error'

# Current state
systemctl --user list-timers mbsync.timer mail-archive.timer
systemctl --user show mbsync.service -p Result -p ExecMainStatus

# Stale mbsync locks (after a killed/wedged run) — safe to remove when none running
pgrep -x mbsync || find ~/Mail/proton -name '*.lock'

# Is Bridge healthy / connected upstream?
ss -tnp | grep 185.70          # ESTAB lines = connected to Proton
journalctl --user -u protonmail-bridge.service --since '-5 min' | grep -iE 'error|unreachable|broken'
```

## Known cosmetic issue

`nixos-rebuild switch` may report `home-manager-todd.service` **failed** with
`timed out waiting on channel`. This is only the HM activation step timing out
while restarting an in-progress mbsync — the config applies correctly regardless.
Verify with the health checks above; the config is fine.
