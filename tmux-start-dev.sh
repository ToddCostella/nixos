#!/usr/bin/env bash

# NixOS Configuration Development Environment Setup Script
# Creates a tmux session with 3 windows for system configuration

BASE_DIR="/home/todd/nixos-config"
SESSION="🛠️ nixos"

# Kill existing session if it exists (safe when called from within tmux)
if tmux has-session -t "$SESSION" 2>/dev/null; then
  # If we're currently attached to this session, switch away first
  if [ -n "$TMUX" ] && [ "$(tmux display-message -p '#S')" = "$SESSION" ]; then
    tmux new-session -d -s "__tmp_safe$$" 2>/dev/null
    tmux switch-client -t "__tmp_safe$$"
  fi
  tmux kill-session -t "$SESSION"
fi

# Create session with first window: Claude AI
tmux new-session -d -s "$SESSION" -n "Claude AI" -c "$BASE_DIR"
tmux send-keys -t "$SESSION:1" 'claude' Enter

# Window 2: Terminal
tmux new-window -t "$SESSION" -n "Terminal" -c "$BASE_DIR"

# Window 3: Yazi
tmux new-window -t "$SESSION" -n "Yazi" -c "$BASE_DIR"
tmux send-keys -t "$SESSION:3" 'y' Enter

# Select window 1 and attach
tmux select-window -t "$SESSION:1"

# Attach if not already in tmux, otherwise switch
if [ -z "$TMUX" ]; then
  tmux attach -t "$SESSION"
else
  tmux switch-client -t "$SESSION"
fi

echo "NixOS configuration environment ready!"
echo "  - Apply changes: sudo nixos-rebuild switch"
echo "  - Test changes:  sudo nixos-rebuild test"
