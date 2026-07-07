#!/usr/bin/env python3
"""
Archive Proton Bridge inbox mail older than N months.

Connects to the local Proton Bridge IMAP server, finds messages in INBOX
older than a cutoff (default 3 months), and moves them to the Archive
folder. In Proton, moving to Archive removes the Inbox label while keeping
the message in All Mail — i.e. it "removes it from the inbox".

Credentials come from environment variables:
    PROTON_BRIDGE_USER   your Proton email address
    PROTON_BRIDGE_PASS   the Bridge-specific password (from the Bridge app,
                         Settings -> your account -> IMAP/SMTP)

Optional:
    PROTON_BRIDGE_HOST   default 127.0.0.1
    PROTON_BRIDGE_PORT   default 1143

Usage:
    python3 archive_old_inbox.py            # DRY RUN: reports only, no changes
    python3 archive_old_inbox.py --apply    # actually move messages
    python3 archive_old_inbox.py --months 6 --apply
"""

import argparse
import email.utils
import imaplib
import os
import sys
from datetime import datetime, timedelta, timezone

ARCHIVE_MAILBOX = "Archive"
BATCH_SIZE = 50  # small batches: Proton Bridge chokes/stalls on large bulk IMAP ops


def log(msg):
    print(msg, flush=True)


def connect():
    host = os.environ.get("PROTON_BRIDGE_HOST", "127.0.0.1")
    port = int(os.environ.get("PROTON_BRIDGE_PORT", "1143"))
    user = os.environ.get("PROTON_BRIDGE_USER")
    password = os.environ.get("PROTON_BRIDGE_PASS")

    if not user or not password:
        sys.exit(
            "ERROR: set PROTON_BRIDGE_USER and PROTON_BRIDGE_PASS environment "
            "variables (Bridge username + Bridge-specific password)."
        )

    # Proton Bridge uses STARTTLS on the IMAP port (self-signed cert on localhost).
    imap = imaplib.IMAP4(host, port)
    imap.starttls()  # uses default SSL context; localhost self-signed cert is fine
    imap.login(user, password)
    return imap


def cutoff_date(months):
    # Approximate a month as 30 days; good enough for a "older than 3 months" cull.
    return datetime.now(timezone.utc) - timedelta(days=30 * months)


def find_old_uids(imap, cutoff):
    """Return UIDs in INBOX whose Date header is strictly before cutoff.

    We SEARCH by BEFORE (server-side, coarse to the day) then re-check each
    message's Date header client-side so the cutoff is exact and TZ-correct.
    """
    imap.select("INBOX")

    # IMAP SEARCH BEFORE uses internal date; format is DD-Mon-YYYY.
    search_str = cutoff.strftime("%d-%b-%Y")
    typ, data = imap.uid("SEARCH", None, "BEFORE", search_str)
    if typ != "OK":
        sys.exit(f"ERROR: IMAP SEARCH failed: {data}")

    uids = data[0].split()
    if not uids:
        return []

    # Confirm each with the actual Date header for an exact cutoff.
    confirmed = []
    for i in range(0, len(uids), BATCH_SIZE):
        chunk = uids[i : i + BATCH_SIZE]
        uid_set = b",".join(chunk)
        typ, fetched = imap.uid("FETCH", uid_set, "(UID BODY.PEEK[HEADER.FIELDS (DATE)])")
        if typ != "OK":
            continue
        # Pair fetch responses (tuples) back to UIDs via the response prefix.
        for item in fetched:
            if not isinstance(item, tuple):
                continue
            prefix = item[0].decode(errors="replace")
            header = item[1].decode(errors="replace")
            uid = prefix.split("UID ")[1].split(")")[0].split()[0] if "UID " in prefix else None
            date_line = ""
            for line in header.splitlines():
                if line.lower().startswith("date:"):
                    date_line = line.split(":", 1)[1].strip()
                    break
            if not date_line or uid is None:
                continue
            try:
                dt = email.utils.parsedate_to_datetime(date_line)
                if dt.tzinfo is None:
                    dt = dt.replace(tzinfo=timezone.utc)
            except (TypeError, ValueError):
                continue
            if dt < cutoff:
                confirmed.append(uid.encode())
    return confirmed


def move_to_archive(imap, uids):
    moved = 0
    for i in range(0, len(uids), BATCH_SIZE):
        chunk = uids[i : i + BATCH_SIZE]
        uid_set = b",".join(chunk)
        # UID MOVE is supported by Proton Bridge (RFC 6851).
        typ, data = imap.uid("MOVE", uid_set, ARCHIVE_MAILBOX)
        if typ != "OK":
            log(f"  WARNING: MOVE failed for a batch: {data}")
            continue
        moved += len(chunk)
        log(f"  moved {moved}/{len(uids)}")
    return moved


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--months", type=int, default=3,
                        help="archive mail older than this many months (default 3)")
    parser.add_argument("--apply", action="store_true",
                        help="actually move messages (default is a dry run)")
    args = parser.parse_args()

    cutoff = cutoff_date(args.months)
    mode = "APPLY" if args.apply else "DRY RUN"
    log(f"[{mode}] Archiving INBOX mail older than {args.months} months "
        f"(before {cutoff.date()}) -> '{ARCHIVE_MAILBOX}'")

    imap = connect()
    try:
        uids = find_old_uids(imap, cutoff)
        log(f"Found {len(uids)} message(s) in INBOX older than the cutoff.")

        if not uids:
            log("Nothing to do.")
            return

        if not args.apply:
            log("DRY RUN — no messages moved. Re-run with --apply to move them.")
            return

        moved = move_to_archive(imap, uids)
        log(f"Done. Moved {moved} message(s) to '{ARCHIVE_MAILBOX}'.")
    finally:
        try:
            imap.logout()
        except Exception:
            pass


if __name__ == "__main__":
    main()
