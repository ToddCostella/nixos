# Remote Terminal Access - tmux + mosh + SSH hardening
# Enables persistent terminal sessions accessible from iOS devices
# via Mosh, and from the desktop via WezTerm + tmux.

{ config, pkgs, ... }:
{
  # tmux - persistent terminal multiplexer
  programs.tmux = {
    enable = true;
    keyMode = "vi";
    baseIndex = 1;
    escapeTime = 0;
    historyLimit = 50000;
    clock24 = true;
    newSession = true;
    terminal = "tmux-256color";
    customPaneNavigationAndResize = true;

    plugins = with pkgs.tmuxPlugins; [
      sensible
      yank
      resurrect
      continuum
      tokyo-night-tmux
    ];

    extraConfigBeforePlugins = ''
      # Plugin settings (must be set before plugins are sourced)
      set -g @continuum-restore 'on'
      set -g @continuum-save-interval '15'
      set -g @tokyo-night-tmux_theme night
    '';

    extraConfig = ''
      # Prefix: Alt-a (M-a)
      set -g prefix M-a
      unbind C-b
      bind M-a send-prefix

      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Status bar at top (hook ensures it runs after tokyo-night-tmux theme)
      set-hook -g after-new-session 'set -g status-position top'
      set-hook -g after-new-window 'set -g status-position top'
      set -g status-position top

      # Mouse support
      set -g mouse on

      # Window switching with Alt+number (no prefix)
      bind -n M-1 select-window -t 1
      bind -n M-2 select-window -t 2
      bind -n M-3 select-window -t 3
      bind -n M-4 select-window -t 4
      bind -n M-5 select-window -t 5
      bind -n M-6 select-window -t 6
      bind -n M-7 select-window -t 7
      bind -n M-8 select-window -t 8
      bind -n M-9 select-window -t 9

      # New window keeps current path
      bind c new-window -c "#{pane_current_path}"

      # Pane splitting with intuitive keys
      bind | split-window -h -c "#{pane_current_path}"
      bind - split-window -v -c "#{pane_current_path}"
      unbind '"'
      unbind %

      # Alt-arrow pane navigation (no prefix)
      bind -n M-Left select-pane -L
      bind -n M-Right select-pane -R
      bind -n M-Up select-pane -U
      bind -n M-Down select-pane -D

      # Vi copy-mode with Wayland clipboard
      bind -T copy-mode-vi v send-keys -X begin-selection
      bind -T copy-mode-vi y send-keys -X copy-pipe-and-cancel "wl-copy"
    '';
  };

  # Mosh - resilient remote connections (auto-opens UDP 60000-61000)
  programs.mosh.enable = true;

  # SSH hardening - key-only auth, no root login
  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
      AllowUsers = [ "todd" ];
    };
  };
}
