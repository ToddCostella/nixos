# Decoupled Maildir email stack — nixos-dev only (imported by todd-desktop.nix).
#
# Architecture:
#   Proton Mail Bridge (systemd user service, 127.0.0.1:1143 IMAP / :1025 SMTP)
#     -> mbsync (isync) pulls into a local Maildir (~/Mail/proton) on a 5-min timer
#     -> notmuch indexes the Maildir for instant local full-text search
#     -> aerc reads the notmuch backend (offline, fast); msmtp sends via the Bridge
#
# Why desktop-scoped: the whole stack depends on the Proton Bridge, which only
# runs on nixos-dev (services.protonmail-bridge in todd-desktop.nix). On the
# headless home-server it would be dead weight with a forever-failing timer.
#
# Secrets: the Bridge password is never in the Nix store. `passCmd` sources
# ~/.secrets.env (injected from 1Password via `refresh-secrets`; see
# todd-base.nix). This works in the minimal systemd-timer env, which has no
# interactive shell and thus no $PROTON_BRIDGE_PASS of its own.
#
# The Bridge's TLS cert is self-signed and lives in its encrypted vault, not on
# disk. `home.activation.exportBridgeCert` extracts it once to bridge.pem so
# mbsync/msmtp can verify it (neither tool has aerc's imap+insecure escape).

{ config, pkgs, lib, ... }:

let
  home = config.home.homeDirectory;
  bridgeCert = "${home}/.config/protonmail/bridge.pem";

  # Weekly Inbox tidy: move INBOX mail older than 3 months to Archive (over
  # Bridge IMAP). In Proton this just drops the Inbox label — the message stays
  # in All Mail, so it is reversible and never deletes anything. The script
  # moves in small batches (50) because Bridge stalls on large bulk IMAP ops.
  archiveScript = ./archive_old_inbox.py;

  # Resolve the Bridge password from ~/.secrets.env (1Password-injected).
  # Falls back to `op read` only if an op session happens to be available.
  passCmd = pkgs.writeShellScript "proton-bridge-pass" ''
    set -eu
    if [ -r "$HOME/.secrets.env" ]; then
      . "$HOME/.secrets.env"
      if [ -n "''${PROTON_BRIDGE_PASS:-}" ]; then
        printf '%s' "$PROTON_BRIDGE_PASS"
        exit 0
      fi
    fi
    # Fallback: 1Password CLI (only works with a live op session).
    /run/wrappers/bin/op read "op://Private/emcficrzzff7fk4z24uq6hmjoi/bridge_password"
  '';

  # mbsync Patterns: allowlist system folders + the two wanted Labels + the one
  # wanted custom Folder, then sweep the rest of those namespaces with excludes.
  # Explicit (non-wildcard) includes take precedence over the wildcard excludes,
  # so the ~19 stale deleted labels never reach the Maildir. Verified with
  # `mbsync -l proton` before the first real sync.
  # NOTE: do NOT hand-quote names with spaces — HM already wraps each list item
  # in quotes when it emits the Patterns line.
  #
  # This isync version does NOT give specific includes precedence over wildcard
  # excludes (a `!Labels/*` sweep would eat the wanted labels too). So we use an
  # explicit denylist: include the whole tree with `*`, then `!`-exclude each
  # stale deleted label by name. The two wanted Labels/ and Folders/Paper Trail
  # are kept simply by NOT being in the exclude list.
  patterns = [
    "*"
    # Exclude All Mail: it is a redundant superset — every message already syncs
    # via Inbox/Archive/Sent/Labels. Worse, a cold reconcile makes mbsync issue
    # one `UID FETCH 1:<82k> (UID FLAGS)`, which Bridge's IMAP engine chokes on
    # (fills the socket, "broken pipe"/"connection reset", sync wedges forever).
    # Dropping it removes the choke and shrinks the local Maildir substantially.
    "!All Mail"
    "!Labels/[Gmail]"
    "!Labels/[Gmail]All Mail"
    "!Labels/[Gmail]Trash"
    "!Labels/[Imap]-Archive"
    "!Labels/[Imap]-Drafts"
    "!Labels/Archive-Archive 2017"
    "!Labels/Deleted Messages"
    "!Labels/Friends"
    "!Labels/Learning"
    "!Labels/Meetup"
    "!Labels/Receipts"
    "!Labels/Work"
    "!Labels/Trip Archive-Cuba 2020"
    "!Labels/Trip Archive-Germany-2016"
    "!Labels/Trip Archive-JavaONE 2015"
    "!Labels/Trip Archive-JavaONE 2016"
    "!Labels/Trip Archive-UK Trip"
    "!Labels/Trip Archive-Vancover 2016"
    "!Labels/Trip Archive-Victoria 2016"
  ];
in
{
  accounts.email = {
    maildirBasePath = "${home}/Mail";
    accounts.proton = {
      primary = true;
      realName = "Todd Costella";
      address = "todd@toddcostella.com";
      # Extra send-from identities aerc offers; msmtp relays regardless of From:.
      aliases = [ "toddcostella@protonmail.com" "toddcostella@gmail.com" ];
      userName = "toddcostella@protonmail.com"; # Bridge login = IMAP/SMTP user
      passwordCommand = "${passCmd}";
      maildir.path = "proton"; # -> ~/Mail/proton

      imap = {
        host = "127.0.0.1";
        port = 1143;
        tls = {
          useStartTls = true;
          certificatesFile = bridgeCert;
        };
      };
      smtp = {
        host = "127.0.0.1";
        port = 1025;
        tls = {
          useStartTls = true;
          certificatesFile = bridgeCert;
        };
      };

      mbsync = {
        enable = true;
        create = "maildir"; # create local mailboxes only
        # Propagate local deletions UP to the server so deleting mail in aerc
        # removes it from Proton too. HM's "imap" maps to mbsync `Remove Far`
        # (delete on the remote/IMAP side only). Deliberately NOT "both" — a
        # vanished remote label never deletes local mail. One-way-safe.
        remove = "imap";
        expunge = "both";
        patterns = patterns;
      };

      msmtp.enable = true;
      notmuch.enable = true; # aerc auto-selects the notmuch:// backend from this
      aerc.enable = true; # generates ~/.config/aerc/accounts.conf
    };
  };

  # Per-account flags above enable notmuch automatically, but mbsync, msmtp, and
  # aerc need their top-level programs.* enabled explicitly.
  programs.mbsync.enable = true;
  programs.msmtp.enable = true;
  programs.aerc = {
    enable = true;
    extraConfig = {
      # aerc refuses to start if accounts.conf isn't 0600; HM writes it world-
      # readable unless we opt into a non-strict file. Our accounts.conf holds
      # no literal secret (auth is via msmtp passwordCommand), so acknowledge it.
      general.unsafe-accounts-conf = true;
      # Message rendering filters (aerc's stock defaults — preserved so HTML /
      # plaintext / calendar parts render correctly under the generated config).
      filters = {
        "text/plain" = "colorize";
        "text/calendar" = "calendar";
        "message/delivery-status" = "colorize";
        "message/rfc822" = "colorize";
        "text/html" = "! html";
        ".headers" = "colorize";
      };
    };
  };

  # notmuch: tag new mail so aerc's default queries (tag:inbox / tag:unread) work.
  programs.notmuch = {
    enable = true;
    new = {
      tags = [ "new" ];
      ignore = [ ".mbsyncstate" ".uidvalidity" ];
    };
    hooks.postNew = ''
      # Route freshly-synced mail: everything tagged 'new' becomes inbox+unread.
      notmuch tag +inbox +unread -new -- tag:new
    '';
  };

  # 5-minute sync timer. Soft-depends on the Bridge; a Bridge blip just yields a
  # failed tick and a retry next interval rather than a broken unit.
  services.mbsync = {
    enable = true;
    frequency = "*:0/5";
    verbose = true;
    postExec = "${pkgs.notmuch}/bin/notmuch new";
  };

  systemd.user.services.mbsync = {
    Unit = {
      After = [ "protonmail-bridge.service" ];
      Wants = [ "protonmail-bridge.service" ];
    };
    Service = {
      Environment = [ "HOME=%h" ];
      # Overlap guard: a full-account sync can exceed the 5-min timer interval.
      # flock -n takes the lock non-blocking and exits 0 (skipping this tick) if
      # another mbsync — timer-driven OR a manual shell run — already holds it,
      # so two syncs can never contend on the maildir/.mbsyncstate locks and
      # deadlock. Overrides the module's ExecStart with the same mbsync command
      # wrapped in flock.
      ExecStart = lib.mkForce (
        "${pkgs.util-linux}/bin/flock -n /run/user/%U/mbsync.lock "
        + "${pkgs.isync}/bin/mbsync --all --verbose"
      );
    };
  };

  # Export the Bridge's self-signed cert to a file mbsync/msmtp can verify
  # against. Requires the Bridge to be running at rebuild time; if it is not,
  # the file stays empty and mbsync fails loudly — just rebuild once it is up.
  home.activation.exportBridgeCert =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      cert="${bridgeCert}"
      if [ ! -s "$cert" ]; then
        run mkdir -p "$(dirname "$cert")"
        ${pkgs.openssl}/bin/openssl s_client -showcerts -starttls imap \
          -connect 127.0.0.1:1143 </dev/null 2>/dev/null \
          | ${pkgs.gnused}/bin/sed -n '/BEGIN CERT/,/END CERT/p' > "$cert" || true
      fi
    '';

  # Weekly Inbox archive. Runs archive_old_inbox.py against Bridge IMAP to move
  # INBOX mail older than 3 months into Archive. Credentials come from the same
  # ~/.secrets.env the Bridge password lives in (PROTON_BRIDGE_PASS), plus the
  # Bridge login as PROTON_BRIDGE_USER. flock shares the mbsync lock so an
  # archive run and a sync can never hit Bridge concurrently.
  systemd.user.services.mail-archive = {
    Unit = {
      Description = "Archive INBOX mail older than 3 months to Archive";
      After = [ "protonmail-bridge.service" ];
      Wants = [ "protonmail-bridge.service" ];
    };
    Service = {
      Type = "oneshot";
      Environment = [
        "HOME=%h"
        "PROTON_BRIDGE_USER=toddcostella@protonmail.com"
      ];
      ExecStart = pkgs.writeShellScript "mail-archive" ''
        set -eu
        if [ -r "$HOME/.secrets.env" ]; then . "$HOME/.secrets.env"; fi
        if [ -z "''${PROTON_BRIDGE_PASS:-}" ]; then
          echo "PROTON_BRIDGE_PASS unset (run refresh-secrets); skipping." >&2
          exit 0
        fi
        export PROTON_BRIDGE_PASS
        exec ${pkgs.util-linux}/bin/flock -n "''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/mbsync.lock" \
          ${pkgs.python3}/bin/python3 ${archiveScript} --apply
      '';
    };
  };

  systemd.user.timers.mail-archive = {
    Unit.Description = "Weekly Inbox archive";
    Timer = {
      OnCalendar = "Mon *-*-* 03:00:00"; # weekly, Monday 3am
      Persistent = true; # catch up if the machine was off at the scheduled time
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
