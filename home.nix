# Home Manager configuration for todd
# Manages user-level dotfiles declaratively alongside system configuration.
#
# Secrets pattern: sensitive values are never stored here. Instead:
#   - SSH keys: managed by 1Password SSH agent (IdentityAgent ~/.1password/agent.sock)
#   - AWS credentials: resolved at runtime via `op --cache inject` (see programs.awscli)
#   - Git signing: uses op-ssh-sign from _1password-gui package
# To add a new secret: reference it via `op://vault/item/field` in a home.file template
# or credential_process entry — no changes to this file's structure required.

{ config, pkgs, lib, ... }:
{
  home.username = "todd";
  home.homeDirectory = "/home/todd";
  home.stateVersion = "24.05";
  programs.home-manager.enable = true;

  # --- Git ---
  programs.git = {
    enable = true;
    signing = {
      format = "ssh";
      signer = "${lib.getExe' pkgs._1password-gui "op-ssh-sign"}";
      key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o";
      signByDefault = true;
    };
    settings = {
      user.name = "Todd Costella";
      user.email = "ToddCostella@gmail.com";
      init.defaultBranch = "main";
      "gpg \"ssh\"".allowedSignersFile = "~/.ssh/allowed_signers";
    };
  };

  # --- Zsh + Oh-My-Zsh ---
  programs.zsh = {
    enable = true;
    oh-my-zsh = {
      enable = true;
      plugins = [ "git" "docker" "docker-compose" "aws" "vi-mode" "fzf" ];
      theme = "robbyrussell";
    };
  };

  # --- Tmux ---
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
      {
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor 'mocha'
          set -g @catppuccin_window_status_style 'rounded'
        '';
      }
      sensible
      yank
      {
        plugin = resurrect;
        extraConfig = "";
      }
      {
        plugin = continuum;
        extraConfig = ''
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '15'
        '';
      }
      {
        plugin = tmux-sessionx;
        extraConfig = ''
          set -g @sessionx-bind 'o'
          set -g @sessionx-zoxide-mode 'on'
          set -g @sessionx-preview-enabled 'true'
          set -g @sessionx-tree-mode 'on'
          set -g @sessionx-custom-paths '~/dev/buoyancy-platform,~/dev/gloom-table,~/nixos-config,~/dev'
        '';
      }
    ];

    extraConfig = ''
      # Prefix: Alt-a (M-a)
      set -g prefix M-a
      unbind C-b
      bind M-a send-prefix

      # True color support
      set -ag terminal-overrides ",xterm-256color:RGB"

      # Status bar at top (hook ensures it runs after catppuccin theme)
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

  # --- SSH client ---
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks."*".extraOptions.IdentityAgent = "~/.1password/agent.sock";
  };

  # --- AWS CLI ---
  programs.awscli = {
    enable = true;
    settings = {
      "default" = {
        region = "ca-west-1";
        output = "json";
      };
      "profile toddcostella" = {
        region = "us-west-2";
        output = "json";
      };
      "profile buoyancy-dev" = {
        role_arn = "arn:aws:iam::779846807083:role/developer-admin";
        source_profile = "default";
        region = "ca-west-1";
        output = "json";
      };
      "profile buoyancy-root" = {
        region = "ca-west-1";
        output = "json";
      };
    };
    credentials = {
      "default" = {
        credential_process = "op --cache inject --in-file ~/.aws/1pw/default.json";
      };
      "toddcostella" = {
        credential_process = "op --cache inject --in-file ~/.aws/1pw/toddcostella.json";
      };
      "buoyancy-root" = {
        credential_process = "op --cache inject --in-file ~/.aws/1pw/buoyancy-root.json";
      };
    };
  };

  # --- 1Password credential templates (op:// URIs — safe to commit) ---
  # Edit the op://vault/item/field references to match your 1Password vault.
  home.file = {
    ".aws/1pw/default.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS default/access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS default/secret_access_key }}";
    };
    ".aws/1pw/toddcostella.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS toddcostella/access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS toddcostella/secret_access_key }}";
    };
    ".aws/1pw/buoyancy-root.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS buoyancy-root/access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS buoyancy-root/secret_access_key }}";
    };
    ".ssh/allowed_signers".text = ''
      ToddCostella@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o
    '';
  };

  # --- User packages ---
  # Dev tools moved here from environment.systemPackages.
  # Note: neovim is installed as a package only — ~/.config/nvim/ is NOT managed here.
  home.packages = with pkgs; [
    neovim
    htop
    lazygit
    lazydocker
    bat
    ripgrep
    fd
    jq
    yq-go
    httpie
    fzf
    yazi
    zoxide
    atuin
    tree
    gh
    slack
    obsidian
    signal-desktop
    zoom-us
    figma-linux
    dbeaver-bin
    bcompare
    wezterm
    aerc
    hugo
    dropbox
    pinta
    apostrophe
    rainfrog
  ];
}
