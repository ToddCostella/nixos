#!/usr/bin/env python3
"""Report top UNCATEGORIZED bulk senders — weekly filter-tuning helper.

Scans recent mail, finds senders that look like newsletters/receipts (List-Id /
List-Unsubscribe / Precedence:bulk headers) but are NOT yet matched by the
current rules in sort_inbox.py. Output is a ready-to-review candidate list for
adding to proton-filters.sieve + sort_inbox.py's RULES.

Reads the live rules from sort_inbox.py (via dest_for), so "already handled" is
always accurate — no duplicated rule list.

Env: PROTON_BRIDGE_USER, PROTON_BRIDGE_PASS (from ~/.secrets.env).
Usage:
    python3 analyze_senders.py                 # scan Inbox + Archive, default 800 each
    python3 analyze_senders.py --box INBOX      # one box
    python3 analyze_senders.py --limit 2000     # deeper scan
"""
import imaplib, os, re, sys, collections

# Import the live categorization so we only surface UNcategorized senders.
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from sort_inbox import dest_for  # noqa: E402

BATCH = 50  # Bridge chokes on large bulk ops


def arg(name, default):
    if name in sys.argv:
        return sys.argv[sys.argv.index(name) + 1]
    return default


def scan(imap, box, limit):
    imap.select(box, readonly=True)
    typ, d = imap.search(None, "ALL")
    uids = d[0].split()
    sample = uids[-limit:] if len(uids) > limit else uids
    bulk = collections.Counter()      # bulk senders not yet categorized
    seen_domains = collections.Counter()
    for i in range(0, len(sample), BATCH):
        chunk = sample[i:i + BATCH]
        typ, fetched = imap.uid("FETCH", b",".join(chunk),
            "(UID BODY.PEEK[HEADER.FIELDS (FROM LIST-ID LIST-UNSUBSCRIBE PRECEDENCE)])")
        for item in fetched:
            if not isinstance(item, tuple):
                continue
            raw = item[1].decode(errors="replace")
            frm = ""
            is_bulk = False
            for line in raw.splitlines():
                low = line.lower()
                if low.startswith("from:"):
                    m = re.search(r"[\w\.\-\+]+@[\w\.\-]+", line)
                    if m:
                        frm = m.group(0).lower()
                if low.startswith(("list-id:", "list-unsubscribe:")) or \
                   ("precedence" in low and "bulk" in low):
                    is_bulk = True
            if not frm:
                continue
            if dest_for(frm):        # already handled by current rules — skip
                continue
            if is_bulk:
                bulk[frm] += 1
    return bulk, len(sample)


def main():
    boxes = [arg("--box", None)] if "--box" in sys.argv else ["INBOX", "Archive"]
    limit = int(arg("--limit", "800"))

    imap = imaplib.IMAP4("127.0.0.1", 1143, timeout=120)
    imap.starttls()
    imap.login(os.environ["PROTON_BRIDGE_USER"], os.environ["PROTON_BRIDGE_PASS"])

    total = collections.Counter()
    for box in boxes:
        bulk, n = scan(imap, box, limit)
        print(f"scanned {n} messages in {box}")
        total.update(bulk)
    imap.logout()

    print("\n=== UNCATEGORIZED bulk senders (not yet in your rules) ===")
    print("count  sender  (add the domain to proton-filters.sieve + sort_inbox.py RULES)\n")
    for sender, c in total.most_common(40):
        dom = sender.split("@")[-1]
        print(f"  {c:4}  {sender:45}  -> domain: {dom}")
    if not total:
        print("  (none — every bulk sender is already categorized)")


if __name__ == "__main__":
    main()
