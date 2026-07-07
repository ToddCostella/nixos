#!/usr/bin/env python3
"""One-time / repeatable INBOX sort by sender -> Proton folders.

Mirrors the Proton Sieve rules (proton-filters.sieve) for mail already sitting
in the Inbox, which server-side filters don't touch retroactively. Moves in
small batches because Proton Bridge stalls on large bulk IMAP ops.

Env: PROTON_BRIDGE_USER, PROTON_BRIDGE_PASS (from ~/.secrets.env).
Usage:
    python3 sort_inbox.py            # DRY RUN — report only
    python3 sort_inbox.py --apply    # actually move
"""
import imaplib, os, re, sys, collections

BATCH = 50  # Bridge chokes on large bulk ops

# domain -> destination folder. Keep in sync with proton-filters.sieve.
FEED = "Folders/The Feed"
PAPER = "Folders/Paper Trail"
RULES = {
    "substack.com": FEED, "frenchtoday.com": FEED, "wakingup.com": FEED,
    "news.wakingup.com": FEED, "frontendmasters.com": FEED, "realpython.com": FEED,
    "purdys.com": FEED, "email.adobe.com": FEED, "techsmith.messages4.com": FEED,
    "email.ricksteves.com": FEED, "infomail.landmarkcinemas.com": FEED,
    "makeawish.ca": FEED, "foodbankscanada.ca": FEED, "artsonview.ca": FEED,
    "mixcloudmail.com": FEED, "acm.org": FEED,
    "makebooks.blurb.com": PAPER, "blurb.com": PAPER,
}

def dest_for(from_addr):
    dom = from_addr.split("@")[-1].lower()
    if dom in RULES:
        return RULES[dom]
    # also match on parent domain (news.foo.com -> foo.com)
    parts = dom.split(".")
    for i in range(len(parts) - 1):
        cand = ".".join(parts[i:])
        if cand in RULES:
            return RULES[cand]
    return None

def main():
    apply = "--apply" in sys.argv
    imap = imaplib.IMAP4("127.0.0.1", 1143, timeout=90); imap.starttls()
    imap.login(os.environ["PROTON_BRIDGE_USER"], os.environ["PROTON_BRIDGE_PASS"])
    imap.select("INBOX")
    typ, d = imap.search(None, "ALL")
    uids = d[0].split()
    print(f"[{'APPLY' if apply else 'DRY RUN'}] scanning {len(uids)} INBOX messages")

    moves = collections.defaultdict(list)  # dest -> [uid,...]
    for i in range(0, len(uids), BATCH):
        chunk = uids[i:i+BATCH]
        typ, fetched = imap.uid("FETCH", b",".join(chunk),
            "(UID BODY.PEEK[HEADER.FIELDS (FROM)])")
        for item in fetched:
            if not isinstance(item, tuple):
                continue
            prefix = item[0].decode(errors="replace")
            m = re.search(r"UID (\d+)", prefix)
            if not m:
                continue
            uid = m.group(1).encode()
            hdr = item[1].decode(errors="replace")
            fa = ""
            fm = re.search(r"[\w\.\-\+]+@[\w\.\-]+", hdr)
            if fm:
                fa = fm.group(0)
            dest = dest_for(fa) if fa else None
            if dest:
                moves[dest].append(uid)

    total = sum(len(v) for v in moves.values())
    for dest, us in moves.items():
        print(f"  {len(us):4} -> {dest}")
    print(f"  {total} message(s) match; {len(uids)-total} stay in Inbox")

    if not apply or total == 0:
        if not apply:
            print("DRY RUN — nothing moved. Re-run with --apply.")
        return

    for dest, us in moves.items():
        for i in range(0, len(us), BATCH):
            batch = us[i:i+BATCH]
            typ, r = imap.uid("MOVE", b",".join(batch), f'"{dest}"')
            print(f"  moved {len(batch)} -> {dest} ({typ})")
    imap.logout()
    print("done")

if __name__ == "__main__":
    main()
