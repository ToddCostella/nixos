#!/usr/bin/env bash

# Home Server Management Environment Setup Script
# Creates a tmux session with windows for managing home-server

HOST="todd@home-server.local"
SESSION="🖥️ home-server"

# Kill existing session if it exists
tmux kill-session -t "$SESSION" 2>/dev/null

# Create session with first window: Shell
tmux new-session -d -s "$SESSION" -n "Shell"
tmux send-keys -t "$SESSION:1" "ssh $HOST" Enter

# Window 2: Logs
tmux new-window -t "$SESSION" -n "Logs"
tmux send-keys -t "$SESSION:2" "ssh $HOST 'sudo journalctl -f'" Enter

# Window 3: AdGuard
tmux new-window -t "$SESSION" -n "AdGuard"
tmux send-keys -t "$SESSION:3" "ssh $HOST 'sudo journalctl -f -u adguardhome'" Enter

# Select window 1 and attach
tmux select-window -t "$SESSION:1"

# Attach if not already in tmux, otherwise switch
if [ -z "$TMUX" ]; then
  tmux attach -t "$SESSION"
else
  tmux switch-client -t "$SESSION"
fi
