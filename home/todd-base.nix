# Home Manager base configuration for todd — headless-safe.
# Applied on all hosts. GUI packages are in todd-desktop.nix.
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

  nixpkgs.config.allowUnfree = true;

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

    initContent = lib.mkMerge [
      # Skip oh-my-zsh's compinit security audit (compaudit). On NixOS, completion
      # dirs live under /nix/store, which is group-writable by `nixbld` by design —
      # compaudit flags that as "insecure" and refuses to load ALL completions.
      # Must be set before oh-my-zsh sources, hence mkBefore. Do NOT "fix" the
      # /nix/store permissions as oh-my-zsh suggests — that breaks Nix builds.
      (lib.mkBefore ''
        ZSH_DISABLE_COMPFIX="true"
      '')

      # herdr zsh completions — only when the herdr overlay is present (nixos-dev).
      # Placed with mkBefore so the completion dir is on fpath BEFORE oh-my-zsh runs
      # its own compinit; otherwise the late-added _herdr is missed by the cached
      # compdump and the completion never loads.
      (lib.mkIf (pkgs ? herdr) (lib.mkBefore ''
        fpath=(${pkgs.runCommand "herdr-zsh-completion" { } ''
          mkdir -p $out
          ${pkgs.herdr}/bin/herdr completion zsh > $out/_herdr
        ''} $fpath)
      ''))
      ''
      # WezTerm Shell Integration - OSC 7 (new tab/pane inherits current directory)
      precmd() {
        print -Pn "\e]7;file://$\{HOSTNAME}$\{PWD}\e\\"
      }

      # Yazi wrapper - cd to last directory on exit
      function y() {
        local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
        yazi "$@" --cwd-file="$tmp"
        IFS= read -r -d "" cwd < "$tmp"
        [ -n "$cwd" ] && [ "$cwd" != "$PWD" ] && builtin cd -- "$cwd"
        rm -f -- "$tmp"
      }

      # Shell tool integrations
      eval "$(atuin init zsh)"
      eval "$(zoxide init zsh)"

      # Load secrets if available (run `refresh-secrets` to update)
      [ -f ~/.secrets.env ] && source ~/.secrets.env

      # Override SSH_AUTH_SOCK to always use 1Password agent.
      # Must be set here (initContent) not sessionVariables — WezTerm overrides
      # SSH_AUTH_SOCK after session vars are set, pointing to its own agent which
      # has no keys and causes passphrase prompts / ssh-askpass dialogs.
      export SSH_AUTH_SOCK="$HOME/.1password/agent.sock"

      # Redirect AWS CDK's synth output out of the buoyancy-platform tree.
      # cdk.out holds ~1.5M throwaway asset dirs that blow past PyCharm's inotify
      # watch budget and stall indexing. Can't set this in cdk.json (that file is
      # committed and runs in CI, where the absolute path won't exist), so scope it
      # to the local shell: export CDK_OUTDIR only while inside the project tree.
      _cdk_outdir_hook() {
        case "$PWD" in
          /home/todd/dev/buoyancy-platform*)
            export CDK_OUTDIR="$HOME/.cache/cdk/buoyancy-platform/cdk.out" ;;
          *)
            unset CDK_OUTDIR ;;
        esac
      }
      autoload -Uz add-zsh-hook
      add-zsh-hook chpwd _cdk_outdir_hook
      _cdk_outdir_hook
      ''
    ];

    shellAliases = {
      # Git
      lg = "lazygit";

      # Python
      acv = "source .venv/bin/activate";

      # Project navigation
      db  = "cd /home/todd/dev/buoyancy-platform/";
      dbf = "cd /home/todd/dev/buoyancy-platform/frontend/";
      dbb = "cd /home/todd/dev/buoyancy-platform/backend";

      # Dev commands
      dc = "docker compose watch backend";
      nb = "npm run dev";

      # Connect to home-server (herdr workspace: Shell + Logs + AdGuard).
      hs = "~/nixos-config/scripts/start-server.sh";

      # Launch the mail workspace (herdr: aerc + shell + yazi + Claude).
      mail = "~/nixos-config/scripts/start-mail.sh";

      # Inject secrets from 1Password into ~/.secrets.env
      refresh-secrets = "op inject --in-file ~/.secrets.env.tpl --out-file ~/.secrets.env --force";
    };

    sessionVariables = {
      PATH = "/home/todd/.local/bin:$PATH";
      # Prevent SSH from falling back to GUI askpass (e.g. during git push/fetch).
      SSH_ASKPASS_REQUIRE = "never";
      # Ensure pandoc (used by Apostrophe) can write temp files.
      TMPDIR = "/tmp";
    };
  };

  # Terminal multiplexing is handled by herdr (see herdr config.toml below),
  # which replaced tmux. The former programs.tmux block lived here.

  # --- SSH client ---
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings."*".IdentityAgent = "~/.1password/agent.sock";
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
        region = "ca-west-1";
        output = "json";
      };
      "profile buoyancy-root" = {
        region = "ca-west-1";
        output = "json";
      };
      # Delegated access: assume OrganizationAccountAccessRole in the prod
      # account (126697143246) using buoyancy-root (mgmt account) as the source.
      # No long-lived prod IAM keys — short-lived STS creds minted per use.
      "profile buoyancy-prod" = {
        region = "ca-west-1";
        output = "json";
        source_profile = "buoyancy-root";
        role_arn = "arn:aws:iam::126697143246:role/OrganizationAccountAccessRole";
        role_session_name = "todd-prod";
      };
    };
    credentials = {
      "default" = {
        credential_process = "op --cache inject --in-file /home/todd/.aws/1pw/default.json";
      };
      "toddcostella" = {
        credential_process = "op --cache inject --in-file /home/todd/.aws/1pw/toddcostella.json";
      };
      "buoyancy-root" = {
        credential_process = "op --cache inject --in-file /home/todd/.aws/1pw/buoyancy-root.json";
      };
      "buoyancy-dev" = {
        credential_process = "op --cache inject --in-file /home/todd/.aws/1pw/buoyancy-dev.json";
      };
      # buoyancy-prod intentionally omitted — it assumes a role via
      # source_profile = buoyancy-root (see profile block above), so it has
      # no static credentials of its own.
    };
  };

  # --- 1Password credential templates (op:// URIs — safe to commit) ---
  home.file = {
    ".aws/1pw/default.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS toddcostella/aws_access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS toddcostella/aws_secret_access_key }}";
    };
    ".aws/1pw/toddcostella.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS toddcostella/aws_access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS toddcostella/aws_secret_access_key }}";
    };
    ".aws/1pw/buoyancy-root.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS buoyancy-root/aws_access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS buoyancy-root/aws_secret_access_key }}";
    };
    ".aws/1pw/buoyancy-dev.json".text = builtins.toJSON {
      Version = 1;
      AccessKeyId = "{{ op://Private/AWS buoyancy-dev/aws_access_key_id }}";
      SecretAccessKey = "{{ op://Private/AWS buoyancy-dev/aws_secret_access_key }}";
    };
    # API key template — run `refresh-secrets` to inject into ~/.secrets.env
    ".secrets.env.tpl".text = ''
      export ANTHROPIC_API_KEY="{{ op://Private/Anthropic API Key/api-key }}"
      export GEMINI_API_KEY="{{ op://Private/Gemini API Key/api-key }}"
      # Proton Mail Bridge password (local IMAP/SMTP on 127.0.0.1:1143/1025).
      # Item title has an '@' so reference by item ID, not name.
      export PROTON_BRIDGE_PASS="{{ op://Private/emcficrzzff7fk4z24uq6hmjoi/bridge_password }}"
    '';

    ".ssh/allowed_signers".text = ''
      ToddCostella@gmail.com ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILR93ztnY9HKCSLlFtwsdrEcwx8ovgpGhJTBB7XS2l5o
    '';

    ".ssh/authorized_keys".text = ''
      ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINl503wq314II0xoFbuRi3gNKsE6fLTWRGs4VmdOMrCk Generated By Termius
    '';

    # superfile vim-style hotkeys. superfile ships no vim toggle — the vim
    # layout is a separate full hotkeys file you swap in for the default
    # hotkeys.toml. Kept as a standalone .toml (not an inline Nix string) so the
    # array literals' '' pairs don't collide with Nix's '' string delimiter.
    # See that file's header for the version-pinning caveat (issue #325).
    ".config/superfile/hotkeys.toml".source = ./superfile-vim-hotkeys.toml;

    # superfile main config — vendored so the [open_with] extension→app map
    # (markdown→apostrophe, text/code→nvim, pdf/images→GUI viewers detached
    # with `setsid -f`) is declarative. GUI apps must detach or they block
    # superfile's TUI until the window closes.
    ".config/superfile/config.toml".source = ./superfile-config.toml;
  }
  # herdr config — only where the herdr overlay is applied (nixos-dev).
  # Mirrors the tmux keybindings above: Alt-a prefix, prefix-free Alt+number to
  # switch tabs (tmux windows), Alt+arrows for pane focus, and | / - splits.
  # herdr "tabs" map to tmux windows, herdr "panes" to tmux panes. tmux `|`
  # (split -h, side-by-side) is herdr's split_vertical (vertical divider); tmux
  # `-` (split -v, stacked) is herdr's split_horizontal — matched by visual result.
  # NOTE: bare Alt chords depend on the outer terminal (WezTerm) not eating them;
  # herdr's docs flag alt+/punctuation bindings as terminal-dependent.
  // lib.optionalAttrs (pkgs ? herdr) {
    ".config/herdr/config.toml".text = ''
      # Managed by home-manager (home/todd-base.nix). Edit there, not here.
      # Reload in a running server with: herdr server reload-config

      [keys]
      prefix = "alt+a"

      # Tabs (≈ tmux windows): Alt+1..9 switches directly, no prefix.
      switch_tab = "alt+1..9"
      new_tab = "prefix+c"

      # Splits: match tmux's visual result (| side-by-side, - stacked).
      split_vertical = "prefix+backslash"
      split_horizontal = "prefix+minus"

      # Pane focus: Alt+arrows, no prefix (mirrors tmux M-Left/Right/Up/Down).
      focus_pane_left = "alt+left"
      focus_pane_right = "alt+right"
      focus_pane_up = "alt+up"
      focus_pane_down = "alt+down"

      [theme]
      # Follow the host terminal's (WezTerm) ANSI palette.
      name = "terminal"

      [ui]
      # tmux `set -g mouse on` + vi copy: auto-copy on selection.
      mouse_capture = true
      copy_on_select = true

      [ui.toast]
      # Show notifications as in-app herdr toasts (not system/terminal).
      delivery = "herdr"

      [ui.sound]
      # No audible notification chimes.
      enabled = false

      # vim-herdr-navigation plugin: Ctrl+h/j/k/l crosses seamlessly between
      # Neovim splits and herdr panes (a vim-tmux-navigator port). The plugin is
      # auto-installed via home.activation below; the Neovim half lives at
      # ~/.config/nvim/after/plugin/herdr_nav.lua (unmanaged, see CLAUDE.md).
      # TRADEOFF: shadows readline Ctrl+L (clear) / Ctrl+K (kill-line) in non-vim
      # panes — the accepted vim-tmux-navigator cost for seamless nav.
      [[keys.command]]
      key = "ctrl+h"
      type = "plugin_action"
      command = "vim-herdr-navigation.left"
      description = "navigate left (vim/herdr)"

      [[keys.command]]
      key = "ctrl+j"
      type = "plugin_action"
      command = "vim-herdr-navigation.down"
      description = "navigate down (vim/herdr)"

      [[keys.command]]
      key = "ctrl+k"
      type = "plugin_action"
      command = "vim-herdr-navigation.up"
      description = "navigate up (vim/herdr)"

      [[keys.command]]
      key = "ctrl+l"
      type = "plugin_action"
      command = "vim-herdr-navigation.right"
      description = "navigate right (vim/herdr)"
    '';
  };

  # --- User packages (CLI tools — headless-safe) ---
  home.packages = with pkgs; [
    neovim
    # --- Neovim LSP servers, formatters, and build deps ---
    # Provided by Nix, NOT Mason: on NixOS Mason's prebuilt binaries crash (bad
    # ELF interp / missing libs — see marksman below). ~/.config/nvim's lsp.lua
    # finds these on $PATH and enables a server only if its binary is present.
    marksman # markdown LSP (Mason's prebuilt binary crashes on NixOS: bad ld interp + missing libicu)
    lua-language-server # lua_ls — for editing this nvim config
    nixd # nixd — Nix LSP (this repo)
    pyright # python LSP
    stylua # lua formatter (conform.nvim)
    nixfmt # nix formatter (conform.nvim) — RFC-style; nixfmt-rfc-style is now aliased to this
    black # python formatter (conform.nvim)
    isort # python import sorter (conform.nvim)
    tree-sitter # treesitter parser compiler CLI (gcc/cc already system-wide)
    btop
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
    superfile
    zoxide
    atuin
    tree
    gh
  ]
  # herdr — terminal workspace manager for AI coding agents. Provided via the
  # herdr flake overlay, which is only applied on nixos-dev, so guard the
  # reference to keep this module valid on hosts without the overlay.
  ++ lib.optional (pkgs ? herdr) pkgs.herdr;

  # herdr plugins are fetched+built by herdr itself into a mutable dir it owns,
  # so they can't be a pure home.file symlink. Install them idempotently on
  # activation instead, pinned to a commit for reproducibility. Guarded on the
  # herdr overlay (nixos-dev only) and skipped entirely if already installed.
  #
  # vim-herdr-navigation: Ctrl+h/j/k/l crosses seamlessly between Neovim splits
  # and herdr panes (see the [[keys.command]] bindings in the herdr config
  # above). The Neovim half lives at ~/.config/nvim/after/plugin/herdr_nav.lua
  # — kept outside home-manager because nvim config is intentionally unmanaged.
  home.activation = lib.optionalAttrs (pkgs ? herdr) {
    herdrPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ! ${pkgs.herdr}/bin/herdr plugin list 2>/dev/null | grep -q vim-herdr-navigation; then
        $DRY_RUN_CMD ${pkgs.herdr}/bin/herdr plugin install \
          paulbkim-dev/vim-herdr-navigation \
          --ref 53e318c772c4d3b7fbd904ac43bcf3e5b5d8b244 --yes \
          || echo "herdr: vim-herdr-navigation install skipped (server not running?)" >&2
      fi
    '';
  };
}
