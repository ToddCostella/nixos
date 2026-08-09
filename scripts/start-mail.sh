#!/usr/bin/env bash

# Mail Environment Setup Script (Herdr edition)
# Creates a Herdr workspace for email: aerc + shell + yazi + Claude.
# Herdr port of the original tmux launcher.
#
# Mapping from the original tmux version:
#   tmux session         -> Herdr workspace
#   tmux window          -> Herdr tab
#   send-keys ... Enter  -> `herdr pane run <pane> "<cmd>"`
#   the "Claude AI" window -> a real Herdr-managed agent (`herdr agent start`)
#
# Idempotent: re-running reuses the workspace and only adds missing tabs
# (does not clobber a running aerc).

set -euo pipefail

BASE_DIR="$HOME"
WORKSPACE_LABEL="📧 mail"

command -v herdr >/dev/null || { echo "herdr not found in PATH" >&2; exit 1; }
command -v jq    >/dev/null || { echo "jq not found in PATH" >&2; exit 1; }
[ "${HERDR_ENV:-}" = 1 ] || echo "warning: not running inside a Herdr pane; targeting the running server anyway" >&2

# aerc's cred-cmd needs $PROTON_BRIDGE_PASS (Proton Bridge password from
# 1Password). Source secrets here so this works even if launched from a shell
# that hasn't loaded them; the aerc pane command re-sources them too (below), so
# aerc sees the var at launch regardless of the pane's shell init timing.
[ -f "$HOME/.secrets.env" ] && source "$HOME/.secrets.env"

# --- helpers -----------------------------------------------------------------

workspace_id() {
  herdr workspace list \
    | jq -r --arg l "$WORKSPACE_LABEL" \
        '.result.workspaces[] | select(.label == $l) | .workspace_id' \
    | head -n1
}

tab_id() {
  local ws="$1" name="$2"
  herdr tab list --workspace "$ws" \
    | jq -r --arg n "$name" \
        '.result.tabs[] | select(.label == $n) | .tab_id' \
    | head -n1
}

tab_root_pane() {
  local ws="$1" tab="$2"
  herdr pane list --workspace "$ws" \
    | jq -r --arg t "$tab" \
        '.result.panes[] | select(.tab_id == $t) | .pane_id' \
    | head -n1
}

# --- workspace ---------------------------------------------------------------

WS="$(workspace_id)"
if [ -z "$WS" ]; then
  WS="$(herdr workspace create --cwd "$BASE_DIR" --label "$WORKSPACE_LABEL" --no-focus \
        | jq -r '.result.workspace.workspace_id')"
  echo "Created workspace $WS"
fi

# Reuse the workspace's initial tab/root pane for the first tab ("aerc").
FIRST_TAB="$(herdr tab list --workspace "$WS" | jq -r '.result.tabs[0].tab_id // empty')"

# --- tab: aerc ---------------------------------------------------------------
if [ -z "$(tab_id "$WS" 'aerc')" ]; then
  if [ -n "$FIRST_TAB" ] \
     && [ "$(herdr tab get "$FIRST_TAB" | jq -r '.result.tab.label')" != 'Shell' ] \
     && [ "$(herdr tab get "$FIRST_TAB" | jq -r '.result.tab.label')" != 'Yazi' ] \
     && [ "$(herdr tab get "$FIRST_TAB" | jq -r '.result.tab.label')" != 'Claude AI' ]; then
    TAB="$FIRST_TAB"
    herdr tab rename "$TAB" 'aerc' >/dev/null
  else
    TAB="$(herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'aerc' --no-focus \
           | jq -r '.result.tab.tab_id')"
  fi
  PANE="$(tab_root_pane "$WS" "$TAB")"
  # Re-source secrets in the pane so aerc's cred-cmd finds PROTON_BRIDGE_PASS at
  # launch, independent of shell-init ordering.
  herdr pane run "$PANE" '[ -f ~/.secrets.env ] && source ~/.secrets.env; aerc' >/dev/null
fi

# --- tab: Shell (general-purpose, in home) ----------------------------------
if [ -z "$(tab_id "$WS" 'Shell')" ]; then
  herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'Shell' --no-focus >/dev/null
fi

# --- tab: Yazi (file browser — attachments / saving files) ------------------
if [ -z "$(tab_id "$WS" 'Yazi')" ]; then
  TAB="$(herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'Yazi' --no-focus \
         | jq -r '.result.tab.tab_id')"
  PANE="$(tab_root_pane "$WS" "$TAB")"
  herdr pane run "$PANE" 'y' >/dev/null
fi

# --- tab: Claude AI (draft / triage email with AI) --------------------------
if [ -z "$(tab_id "$WS" 'Claude AI')" ]; then
  TAB="$(herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'Claude AI' --no-focus \
         | jq -r '.result.tab.tab_id')"
  PANE="$(tab_root_pane "$WS" "$TAB")"
  # Agent names must be unique across the whole Herdr session; mail-claude is
  # distinct from nixos-claude / dev-claude used by the other launchers.
  herdr agent start mail-claude --kind claude --pane "$PANE" >/dev/null \
    || herdr pane run "$PANE" 'claude' >/dev/null
fi

# --- focus the aerc tab and surface the workspace ---------------------------

AERC_TAB="$(tab_id "$WS" 'aerc')"
[ -n "$AERC_TAB" ] && herdr tab focus "$AERC_TAB" >/dev/null
herdr workspace focus "$WS" >/dev/null

echo "Mail environment setup complete!"
