#!/usr/bin/env bash

# Open home-server SSH connections as windows in the current tmux session.

HOST="todd@home-server.local"

# Get current session name
SESSION=$(tmux display-message -p '#S')

tmux new-window -t "$SESSION" -n "🖥️ shell"
tmux send-keys -t "$SESSION:🖥️ shell" "ssh $HOST" Enter

tmux new-window -t "$SESSION" -n "🖥️ logs"
tmux send-keys -t "$SESSION:🖥️ logs" "ssh $HOST 'sudo journalctl -f'" Enter

tmux new-window -t "$SESSION" -n "🖥️ adguard"
tmux send-keys -t "$SESSION:🖥️ adguard" "ssh $HOST 'sudo journalctl -f -u adguardhome'" Enter

tmux select-window -t "$SESSION:🖥️ shell"
