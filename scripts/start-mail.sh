#!/usr/bin/env bash

# Mail Environment Setup Script
# Creates a tmux session for email: aerc + shell + yazi + Claude.
# Idempotent — re-running attaches to the existing session and only adds
# any windows that are missing (does not clobber a running aerc).

BASE_DIR="$HOME"
SESSION="📧 mail"

# aerc's cred-cmd needs $PROTON_BRIDGE_PASS (Proton Bridge password from
# 1Password). Source secrets here so the session works even if launched from
# a shell that hasn't loaded them. Also export it into the tmux server env so
# new panes/windows inherit it.
[ -f "$HOME/.secrets.env" ] && source "$HOME/.secrets.env"
[ -n "$PROTON_BRIDGE_PASS" ] && tmux setenv -g PROTON_BRIDGE_PASS "$PROTON_BRIDGE_PASS" 2>/dev/null

# Returns true if a window with the given name exists in the session
window_exists() {
  tmux list-windows -t "$SESSION" -F "#{window_name}" 2>/dev/null | grep -qxF "$1"
}

# NOTE: the session name contains an emoji + space, which breaks
# "session:window" name-based targets (tmux mis-parses the colon target).
# Target windows by INDEX instead, and capture each new window's id so
# send-keys is unambiguous.

if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  # Fresh start: create session with first window running aerc
  tmux new-session -d -s "$SESSION" -n "aerc" -c "$BASE_DIR"
  aerc_win=$(tmux list-windows -t "$SESSION" -F "#{window_id}" | tail -1)
  tmux send-keys -t "$aerc_win" 'aerc' Enter
fi

# Window: Shell (general-purpose, in home)
if ! window_exists "Shell"; then
  tmux new-window -t "$SESSION" -n "Shell" -c "$BASE_DIR"
fi

# Window: Yazi (file browser — handy for attachments / saving files)
if ! window_exists "Yazi"; then
  win=$(tmux new-window -t "$SESSION" -n "Yazi" -c "$BASE_DIR" -PF "#{window_id}")
  tmux send-keys -t "$win" 'y' Enter
fi

# Window: Claude AI (draft / triage email with AI)
if ! window_exists "Claude AI"; then
  win=$(tmux new-window -t "$SESSION" -n "Claude AI" -c "$BASE_DIR" -PF "#{window_id}")
  tmux send-keys -t "$win" 'claude' Enter
fi

# Select the aerc window and attach (target by name is fine for select-window
# via -t with the window name resolved through list; use index 1 to be safe)
tmux select-window -t "$SESSION:1"

# Attach if not already in tmux, otherwise switch
if [ -z "$TMUX" ]; then
  tmux attach -t "$SESSION"
else
  tmux switch-client -t "$SESSION"
fi

echo "Mail environment setup complete!"
