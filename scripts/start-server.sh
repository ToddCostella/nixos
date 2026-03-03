#!/usr/bin/env bash

# Launch a tmux session on home-server and attach to it.
# The remote session uses a red status bar so it's visually distinct
# from local sessions.

HOST="todd@home-server.local"
SESSION="🖥️ home-server"

ssh -t "$HOST" bash <<'REMOTE'
SESSION="🖥️ home-server"

# If session already exists, just attach
if tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux attach -t "$SESSION"
  exit 0
fi

# Create session - Window 1: shell
tmux new-session -d -s "$SESSION" -n "Shell"

# Window 2: logs (journalctl follow)
tmux new-window -t "$SESSION" -n "Logs"
tmux send-keys -t "$SESSION:2" 'sudo journalctl -f' Enter

# Window 3: AdGuard log
tmux new-window -t "$SESSION" -n "AdGuard"
tmux send-keys -t "$SESSION:3" 'sudo journalctl -f -u adguardhome' Enter

# Red status bar to distinguish from local sessions
tmux set-option -t "$SESSION" status-style "bg=colour160,fg=colour255"
tmux set-option -t "$SESSION" window-status-current-style "bg=colour88,fg=colour255,bold"
tmux set-option -t "$SESSION" status-left "#[bg=colour88,fg=colour255,bold] 🖥️ home-server #[default] "
tmux set-option -t "$SESSION" status-right "#[fg=colour255] %H:%M %d-%b "

tmux select-window -t "$SESSION:1"
tmux attach -t "$SESSION"
REMOTE
