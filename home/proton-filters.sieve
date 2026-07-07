# Proton Mail Sieve filters — inbox categorization
# ------------------------------------------------------------------
# Paste this into Proton web: Settings -> Filters -> Add sieve filter.
# It sorts incoming mail by sender into two folders:
#   Folders/The Feed    — newsletters / promotional / content you read
#   Folders/Paper Trail — receipts / transactional records
#
# Rules are sender-domain / address based (first-pass, precise). Ambiguous
# senders that send BOTH receipts and marketing (Amazon, Namecheap, WestJet,
# Petro-Canada, VRBO) are deliberately NOT filtered — they stay in the Inbox
# so no real receipt gets buried. Add them later once you decide.
#
# "fileinto" in Proton moves the message into the folder (removes it from the
# Inbox). Order matters: first match wins because each block "stop"s.
# NOTE: fileinto uses Proton's folder DISPLAY NAME ("The Feed"), NOT the Bridge
# IMAP path ("Folders/The Feed"). The companion sort_inbox.py works over IMAP
# and DOES use the "Folders/..." path — the two intentionally differ.
#
# To extend: add the sender's domain/address to the appropriate address test.
# Keep this file as the source of truth; re-paste after edits.

require ["fileinto"];

# ---- The Feed: newsletters, learning content, promotions, charities ----
if anyof (
    address :domain "from" "substack.com",
    address :domain "from" "frenchtoday.com",
    address :domain "from" "wakingup.com",
    address :domain "from" "news.wakingup.com",
    address :domain "from" "frontendmasters.com",
    address :domain "from" "realpython.com",
    address :domain "from" "purdys.com",
    address :domain "from" "email.adobe.com",
    address :domain "from" "techsmith.messages4.com",
    address :domain "from" "email.ricksteves.com",
    address :domain "from" "infomail.landmarkcinemas.com",
    address :domain "from" "makeawish.ca",
    address :domain "from" "foodbankscanada.ca",
    address :domain "from" "artsonview.ca",
    address :domain "from" "mixcloudmail.com",
    address :domain "from" "acm.org"
) {
    fileinto "The Feed";
    stop;
}

# ---- Paper Trail: receipts / order confirmations / transactional ----
if anyof (
    address :domain "from" "makebooks.blurb.com",
    address :domain "from" "blurb.com"
) {
    fileinto "Paper Trail";
    stop;
}
