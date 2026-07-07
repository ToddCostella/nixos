#!/usr/bin/env python3
"""Empty Spam and Trash on Proton Bridge via IMAP (mark \\Deleted + EXPUNGE).

Reports counts before and after. Set PROTON_BRIDGE_USER / PROTON_BRIDGE_PASS.
Pass --report to only show counts without deleting.
"""
import imaplib, os, sys

REPORT_ONLY = "--report" in sys.argv

imap = imaplib.IMAP4("127.0.0.1", 1143, timeout=60)
imap.starttls()
imap.login(os.environ["PROTON_BRIDGE_USER"], os.environ["PROTON_BRIDGE_PASS"])

for box in ["Spam", "Trash"]:
    typ, sel = imap.select(box)  # read-write
    before = int(sel[0])
    print(f"{box}: {before} messages", flush=True)
    if REPORT_ONLY or before == 0:
        continue
    typ, d = imap.search(None, "ALL")
    uids = d[0].split()
    imap.store(b",".join(uids), "+FLAGS", r"(\Deleted)")
    imap.expunge()
    typ, sel2 = imap.select(box, readonly=True)
    after = int(sel2[0])
    print(f"  -> expunged; {box} now {after} messages", flush=True)

imap.logout()
print("done", flush=True)
