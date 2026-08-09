#!/usr/bin/env bash

# Home Server Management Environment Setup Script (Herdr edition)
# Creates a Herdr workspace with tabs for managing home-server.
# Herdr port of the original tmux launcher.
#
# Mapping from the original tmux version:
#   tmux session         -> Herdr workspace
#   tmux window          -> Herdr tab
#   send-keys ... Enter  -> `herdr pane run <pane> "<cmd>"`
#
# Idempotent: re-running reuses the workspace and only creates missing tabs.

set -euo pipefail

HOST="todd@home-server.local"
WORKSPACE_LABEL="🖥️ home-server"

command -v herdr >/dev/null || { echo "herdr not found in PATH" >&2; exit 1; }
command -v jq    >/dev/null || { echo "jq not found in PATH" >&2; exit 1; }
[ "${HERDR_ENV:-}" = 1 ] || echo "warning: not running inside a Herdr pane; targeting the running server anyway" >&2

# --- helpers -----------------------------------------------------------------

# Print the workspace id for our label, or empty if it doesn't exist yet.
workspace_id() {
  herdr workspace list \
    | jq -r --arg l "$WORKSPACE_LABEL" \
        '.result.workspaces[] | select(.label == $l) | .workspace_id' \
    | head -n1
}

# Print the tab id with the given label within our workspace, or empty.
tab_id() {
  local ws="$1" name="$2"
  herdr tab list --workspace "$ws" \
    | jq -r --arg n "$name" \
        '.result.tabs[] | select(.label == $n) | .tab_id' \
    | head -n1
}

# Print the root pane id of a tab.
tab_root_pane() {
  local ws="$1" tab="$2"
  herdr pane list --workspace "$ws" \
    | jq -r --arg t "$tab" \
        '.result.panes[] | select(.tab_id == $t) | .pane_id' \
    | head -n1
}

# Create a fresh tab with the given label and run a command in its root pane.
# Idempotent by label: a no-op if the tab already exists.
ensure_tab_running() {
  local ws="$1" label="$2" cmd="$3"
  [ -n "$(tab_id "$ws" "$label")" ] && return 0

  local tab pane
  tab="$(herdr tab create --workspace "$ws" --label "$label" --no-focus \
         | jq -r '.result.tab.tab_id')"
  pane="$(tab_root_pane "$ws" "$tab")"
  herdr pane run "$pane" "$cmd" >/dev/null
}

# --- workspace ---------------------------------------------------------------

FRESH_WS=0
WS="$(workspace_id)"
if [ -z "$WS" ]; then
  WS="$(herdr workspace create --label "$WORKSPACE_LABEL" --no-focus \
        | jq -r '.result.workspace.workspace_id')"
  FRESH_WS=1
  echo "Created workspace $WS"
fi

# A freshly-created workspace comes with one stray initial tab. Claim it for the
# first tab (Shell) by renaming + running in it, so we don't leave an empty tab.
# On an existing workspace we never touch tab 0 (it may be real work).
if [ "$FRESH_WS" = 1 ]; then
  FIRST_TAB="$(herdr tab list --workspace "$WS" | jq -r '.result.tabs[0].tab_id // empty')"
  if [ -n "$FIRST_TAB" ]; then
    herdr tab rename "$FIRST_TAB" 'Shell' >/dev/null
    herdr pane run "$(tab_root_pane "$WS" "$FIRST_TAB")" "ssh $HOST" >/dev/null
  fi
fi

# --- tabs (idempotent; each creates a fresh tab only if missing) ------------

ensure_tab_running "$WS" 'Shell'   "ssh $HOST"
ensure_tab_running "$WS" 'Logs'    "ssh $HOST 'sudo journalctl -f'"
ensure_tab_running "$WS" 'AdGuard' "ssh $HOST 'sudo journalctl -f -u adguardhome'"

# --- focus the Shell tab and surface the workspace --------------------------

SHELL_TAB="$(tab_id "$WS" 'Shell')"
[ -n "$SHELL_TAB" ] && herdr tab focus "$SHELL_TAB" >/dev/null
herdr workspace focus "$WS" >/dev/null

echo "Home server management environment ready!"
