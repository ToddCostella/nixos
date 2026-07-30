#!/usr/bin/env bash

# NixOS Configuration Development Environment Setup Script (Herdr edition)
# Creates a Herdr workspace with 3 tabs for working on this config.
# This is the Herdr port of the original tmux script (kept as tmux-start-dev.sh).
#
# Mapping from the tmux version:
#   tmux session  -> Herdr workspace
#   tmux window   -> Herdr tab
#   send-keys ... Enter -> `herdr pane run <pane> "<cmd>"`
#   the "Claude AI" window -> a real Herdr-managed agent (`herdr agent start`)
#
# Unlike the tmux version this is idempotent: re-running reuses the workspace and
# only creates tabs that are missing, instead of killing and rebuilding.

set -euo pipefail

BASE_DIR="/home/todd/nixos-config"
WORKSPACE_LABEL="🛠️ nixos"

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

# --- workspace ---------------------------------------------------------------

WS="$(workspace_id)"
if [ -z "$WS" ]; then
  WS="$(herdr workspace create --cwd "$BASE_DIR" --label "$WORKSPACE_LABEL" --no-focus \
        | jq -r '.result.workspace.workspace_id')"
  echo "Created workspace $WS"
fi

# The workspace is created with an initial tab/root pane; reuse it for the first
# tab ("Claude AI") instead of leaving an empty stray tab.
FIRST_TAB="$(herdr tab list --workspace "$WS" | jq -r '.result.tabs[0].tab_id // empty')"

# --- tab: Claude AI (a Herdr-managed agent) ---------------------------------
if [ -z "$(tab_id "$WS" 'Claude AI')" ]; then
  if [ -n "$FIRST_TAB" ] && [ "$(herdr tab get "$FIRST_TAB" | jq -r '.result.tab.label')" != 'Terminal' ]; then
    TAB="$FIRST_TAB"
    herdr tab rename "$TAB" 'Claude AI' >/dev/null
  else
    TAB="$(herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'Claude AI' --no-focus \
           | jq -r '.result.tab.tab_id')"
  fi
  PANE="$(tab_root_pane "$WS" "$TAB")"
  # Start Claude as a first-class Herdr agent so its lifecycle (idle/working/
  # blocked/done) is tracked, rather than just piping `claude` into a shell.
  # Agent names must be unique across the whole Herdr session, so this uses
  # nixos-claude (distinct from the buoyancy script's dev-claude).
  herdr agent start nixos-claude --kind claude --pane "$PANE" >/dev/null \
    || herdr pane run "$PANE" 'claude' >/dev/null
fi

# --- tab: Terminal (bare shell) ---------------------------------------------
if [ -z "$(tab_id "$WS" 'Terminal')" ]; then
  herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'Terminal' --no-focus >/dev/null
fi

# --- tab: Yazi (y) -----------------------------------------------------------
if [ -z "$(tab_id "$WS" 'Yazi')" ]; then
  TAB="$(herdr tab create --workspace "$WS" --cwd "$BASE_DIR" --label 'Yazi' --no-focus \
         | jq -r '.result.tab.tab_id')"
  PANE="$(tab_root_pane "$WS" "$TAB")"
  herdr pane run "$PANE" 'y' >/dev/null
fi

# --- focus the Claude AI tab and surface the workspace ----------------------
CLAUDE_TAB="$(tab_id "$WS" 'Claude AI')"
[ -n "$CLAUDE_TAB" ] && herdr tab focus "$CLAUDE_TAB" >/dev/null
herdr workspace focus "$WS" >/dev/null

echo "NixOS configuration environment ready!"
echo "  - Apply changes: sudo nixos-rebuild switch --flake $BASE_DIR#nixos-dev"
echo "  - Test changes:  sudo nixos-rebuild test   --flake $BASE_DIR#nixos-dev"
