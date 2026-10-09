# Omarchy-flavoured Hyprland session (user side).
#
# Borrowed from Omarchy (github.com/basecamp/omarchy) by way of omarchy-nix
# (github.com/henrysipp/omarchy-nix): the keybinding scheme, gaps/borders/
# animations, Waybar layout, Mako/Hyprlock/Hypridle setup and a switchable colour
# theme. Rebuilt here as plain Home Manager config rather than importing
# omarchy-nix, which is unmaintained, pinned to nixos-25.05, and would take over
# git/zsh/terminal config this repo already manages.
#
# Hyprland runs ALONGSIDE GNOME: pick "Hyprland" or "GNOME" from the GDM session
# menu (gear icon). The system side lives in modules/desktop-hyprland.nix.
#
# Every user service here is bound to hyprland-session.target (not
# graphical-session.target) so none of it starts inside a GNOME session.
#
# Bindings deliberately keep this repo's GNOME/Forge muscle memory where it
# clashed with Omarchy: Super+h/j/k/l focus, Super+F fullscreen, Super+E files,
# Super+Shift+Q close (Omarchy's Super+W also works). Super+K's Omarchy
# cheat-sheet moved to Super+/ because K is focus-up here.
#
# Config format: hyprlang (~/.config/hypr/hyprland.conf). Hyprland 0.56 also
# reads Lua and Home Manager defaults to it for stateVersion >= 26.05; this repo
# is on 24.05, and configType is pinned so a stateVersion bump doesn't silently
# rewrite the session config.
{ config, lib, pkgs, ... }:
let
  cfg = config.desktop;
  themes = import ./themes.nix;
  c = themes.${cfg.theme};

  rgb = hex: "rgb(${hex})";
  rgba = hex: alpha: "rgba(${hex}${alpha})";

  terminal = "wezterm";
  browser = "firefox";
  # Omarchy-style "web apps": a site in its own chromeless window.
  webapp = url: "google-chrome-stable --app=${url}";

  sessionTarget = "hyprland-session.target";

  # Super+/ — searchable list of every binding that has a description (bindd).
  # Reads the live config via hyprctl, so it never drifts from what's bound.
  showKeybindings = pkgs.writeShellScriptBin "hypr-show-keybindings" ''
    ${pkgs.hyprland}/bin/hyprctl binds -j | ${pkgs.jq}/bin/jq -r '
      def bit($n): ((.modmask / $n) | floor) % 2 == 1;
      .[] | select(.has_description)
      | ([ (if bit(64) then "SUPER" else empty end),
           (if bit(4)  then "CTRL"  else empty end),
           (if bit(8)  then "ALT"   else empty end),
           (if bit(1)  then "SHIFT" else empty end),
           .key ] | join(" + ")) as $combo
      | (30 - ($combo | length)) as $pad
      | $combo + (if $pad > 0 then " " * $pad else " " end) + .description
    ' | ${pkgs.walker}/bin/walker --dmenu -p "Keybindings"
  '';

  # Super+Escape — Omarchy-style power menu.
  powerMenu = pkgs.writeShellScriptBin "hypr-power-menu" ''
    choice=$(printf '%s\n' "󰌾  Lock" "󰤄  Suspend" "󰍃  Log out" "󰜉  Reboot" "󰐥  Shut down" \
      | ${pkgs.walker}/bin/walker --dmenu -p "Power")
    case "$choice" in
      *Lock)       loginctl lock-session ;;
      *Suspend)    systemctl suspend ;;
      *"Log out")  ${pkgs.hyprland}/bin/hyprctl dispatch exit ;;
      *Reboot)     systemctl reboot ;;
      *"Shut down") systemctl poweroff ;;
    esac
  '';

  workspaceBinds = lib.concatMap (n:
    let key = toString (lib.mod n 10); in [
      "SUPER, ${key}, Workspace ${toString n}, workspace, ${toString n}"
      "SUPER SHIFT, ${key}, Move window to workspace ${toString n}, movetoworkspace, ${toString n}"
    ]) (lib.range 1 10);
in
{
  options.desktop = {
    theme = lib.mkOption {
      type = lib.types.enum (builtins.attrNames themes);
      default = "tokyo-night";
      description = "Colour palette for the Hyprland session (see ./themes.nix).";
    };
    wallpaper = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = lib.literalExpression "./wallpapers/mountains.jpg";
      description = "Wallpaper image. null paints a solid background from the theme.";
    };
  };

  config = {
    # Bind every wayland-session user service (waybar, hypridle, swayosd,
    # hyprpolkitagent, ...) to Hyprland only — never to GNOME's session.
    wayland.systemd.target = sessionTarget;

    home.packages = (with pkgs; [
      hyprshot      # screenshots (grim/slurp work on Hyprland, unlike Mutter)
      hyprpicker    # colour picker
      swaybg        # wallpaper / solid background
      wl-clip-persist
      pavucontrol
    ]) ++ [ showKeybindings powerMenu ];

    wayland.windowManager.hyprland = {
      enable = true;
      # Use the NixOS-provided Hyprland (programs.hyprland) instead of a second copy.
      package = null;
      portalPackage = null;
      configType = "hyprlang";
      systemd = {
        enable = true;  # provides hyprland-session.target
        # Import the whole session env into systemd/D-Bus: Walker/Elephant run as
        # user services and need XDG_DATA_DIRS (app discovery) and PATH, and apps
        # they launch should see NIXOS_OZONE_WL etc.
        variables = [ "--all" ];
      };

      settings = {
        # --- Monitors: laptop left, U3219Q (32") middle, U2723QE (27") right ---
        #
        # Matched on `desc:` (make + model + serial), NOT connector names. DP-2
        # and DP-3 swap between the two Dells depending on power/plug order —
        # observed swapping within a single session on 2026-10-08 — so a
        # connector-keyed rule silently lands windows on the wrong screen.
        #
        # x offsets are in SCALED (logical) pixels, so each equals the sum of the
        # effective widths to its left:
        #   eDP-1   3840/2   = 1920 wide -> starts at 0
        #   U3219Q  3840/1.5 = 2560 wide -> starts at 1920
        #   U2723QE 2560/1   = 2560 wide -> starts at 4480
        # Get these wrong and the pointer hits a dead gap between displays.
        #
        # The U2723QE runs 2560x1440@60 rather than its only 4K mode (3840x2160
        # @29.98Hz) — 30Hz makes pointer movement feel laggy. Swap the mode here
        # if sharpness matters more than smoothness.
        #
        # NOTE: these panels often refuse a mode set live via `hyprctl keyword
        # monitor` (atomic DRM commit fails, monitor reports 0x0) but accept the
        # same mode on `hyprctl reload`. Apply changes with a reload, not live
        # keyword commands.
        monitor = [
          "desc:Sharp Corporation 0x14D6,3840x2400@59.99,0x0,2"
          "desc:Dell Inc. DELL U3219Q 3BXJ413,3840x2160@60.00,1920x0,1.5"
          "desc:Dell Inc. DELL U2723QE JHFW0P3,2560x1440@59.95,4480x0,1"
          # Fallback so an unknown display still lights up instead of staying dark.
          ",preferred,auto,auto"
        ];

        env = [
          "XCURSOR_SIZE,24"
          "HYPRCURSOR_SIZE,24"
          "XCURSOR_THEME,Adwaita"
          "ELECTRON_OZONE_PLATFORM_HINT,wayland"
          "SDL_VIDEODRIVER,wayland"
        ];

        exec-once = [
          (if cfg.wallpaper != null
            then "swaybg -i ${cfg.wallpaper} -m fill"
            else "swaybg -c '#${c.bg}'")
          "wl-clip-persist --clipboard regular"
        ];

        general = {
          gaps_in = 5;
          gaps_out = 10;
          border_size = 2;
          "col.active_border" = "${rgba c.accent "ee"} ${rgba c.accent2 "ee"} 45deg";
          "col.inactive_border" = rgba c.overlay "aa";
          resize_on_border = false;
          allow_tearing = false;
          layout = "dwindle";
        };

        decoration = {
          rounding = 4;
          shadow = {
            enabled = true;
            range = 2;
            render_power = 3;
            color = "rgba(1a1a1aee)";
          };
          blur = {
            enabled = true;
            size = 3;
            passes = 1;
            vibrancy = 0.1696;
          };
        };

        animations = {
          enabled = true;
          bezier = [
            "easeOutQuint,0.23,1,0.32,1"
            "easeInOutCubic,0.65,0.05,0.36,1"
            "linear,0,0,1,1"
            "almostLinear,0.5,0.5,0.75,1.0"
            "quick,0.15,0,0.1,1"
          ];
          animation = [
            "global, 1, 10, default"
            "border, 1, 5.39, easeOutQuint"
            "windows, 1, 4.79, easeOutQuint"
            "windowsIn, 1, 4.1, easeOutQuint, popin 87%"
            "windowsOut, 1, 1.49, linear, popin 87%"
            "fadeIn, 1, 1.73, almostLinear"
            "fadeOut, 1, 1.46, almostLinear"
            "fade, 1, 3.03, quick"
            "layers, 1, 3.81, easeOutQuint"
            "layersIn, 1, 4, easeOutQuint, fade"
            "layersOut, 1, 1.5, linear, fade"
            "fadeLayersIn, 1, 1.79, almostLinear"
            "fadeLayersOut, 1, 1.39, almostLinear"
            "workspaces, 0, 0, ease"
          ];
        };

        dwindle = {
          preserve_split = true;
          force_split = 2;
        };

        input = {
          kb_layout = "us";
          follow_mouse = 1;
          sensitivity = 0;
          touchpad = {
            natural_scroll = true;  # GNOME's default; match it
            tap-to-click = true;
          };
        };

        # Three-finger horizontal swipe switches workspace.
        gesture = [ "3, horizontal, workspace" ];

        xwayland.force_zero_scaling = true;

        misc = {
          disable_hyprland_logo = true;
          disable_splash_rendering = true;
          focus_on_activate = true;
        };

        ecosystem = {
          no_update_news = true;
          no_donation_nag = true;
        };

        windowrule = [
          "match:class .*, suppress_event maximize"
          # A dash of transparency, opaque for video/meetings/browsers.
          "match:class .*, opacity 0.97 0.9"
          "match:class ^(firefox|google-chrome|zen.*)$, opacity 1 0.97"
          "match:class ^(zoom|vlc|mpv|org.gnome.Loupe)$, opacity 1 1"
          "match:class ^(org.pulseaudio.pavucontrol|.blueman-manager-wrapped|nm-connection-editor)$, float on"
          "match:class ^(1password)$, float on"
          "match:class ^(1password)$, center on"
        ];

        layerrule = [
          "match:namespace waybar, blur on"
          "match:namespace walker, blur on"
          "match:namespace walker, ignore_alpha 0.5"
        ];

        # bindd = MODS, key, description, dispatcher, args — the description
        # feeds the Super+/ cheat-sheet.
        bindd = [
          # Launchers
          "SUPER, space, App launcher, exec, walker"
          "SUPER, return, Terminal, exec, ${terminal}"
          "SUPER, B, Browser, exec, ${browser}"
          "SUPER SHIFT, W, Browser, exec, ${browser}"
          "SUPER, E, File manager, exec, nautilus --new-window"
          "SUPER, N, Neovim, exec, ${terminal} start -- nvim"
          "SUPER, T, Activity (btop), exec, ${terminal} start -- btop"
          "SUPER, D, Docker (lazydocker), exec, ${terminal} start -- lazydocker"
          "SUPER, A, Claude, exec, claude-desktop"
          "SUPER, O, Obsidian, exec, obsidian"
          "SUPER, G, Signal, exec, signal-desktop"
          "SUPER SHIFT, slash, 1Password, exec, 1password"
          "SUPER, Y, YouTube, exec, ${webapp "https://youtube.com"}"
          "SUPER, slash, Show keybindings, exec, hypr-show-keybindings"
          "SUPER CTRL, V, Clipboard history, exec, walker -m clipboard"
          "SUPER CTRL, E, Emoji picker, exec, walker -m symbols"

          # Windows
          "SUPER, W, Close window, killactive,"
          "SUPER SHIFT, Q, Close window, killactive,"
          "SUPER, F, Fullscreen, fullscreen, 0"
          "SUPER ALT, F, Maximize, fullscreen, 1"
          "SUPER, V, Toggle floating, togglefloating,"
          "SUPER, P, Pseudo-tile, pseudo,"
          "SUPER, backslash, Toggle split direction, layoutmsg, togglesplit"

          # Focus / move (hjkl from Forge, arrows from Omarchy)
          "SUPER, h, Focus left, movefocus, l"
          "SUPER, j, Focus down, movefocus, d"
          "SUPER, k, Focus up, movefocus, u"
          "SUPER, l, Focus right, movefocus, r"
          "SUPER, left, Focus left, movefocus, l"
          "SUPER, down, Focus down, movefocus, d"
          "SUPER, up, Focus up, movefocus, u"
          "SUPER, right, Focus right, movefocus, r"
          "SUPER SHIFT, h, Swap left, swapwindow, l"
          "SUPER SHIFT, j, Swap down, swapwindow, d"
          "SUPER SHIFT, k, Swap up, swapwindow, u"
          "SUPER SHIFT, l, Swap right, swapwindow, r"
          "SUPER SHIFT, left, Swap left, swapwindow, l"
          "SUPER SHIFT, down, Swap down, swapwindow, d"
          "SUPER SHIFT, up, Swap up, swapwindow, u"
          "SUPER SHIFT, right, Swap right, swapwindow, r"

          # Resize
          "SUPER, minus, Shrink width, resizeactive, -100 0"
          "SUPER, equal, Grow width, resizeactive, 100 0"
          "SUPER SHIFT, minus, Shrink height, resizeactive, 0 -100"
          "SUPER SHIFT, equal, Grow height, resizeactive, 0 100"

          # Workspaces
          "SUPER, comma, Previous workspace, workspace, -1"
          "SUPER, period, Next workspace, workspace, +1"
          "SUPER, tab, Last workspace, workspace, previous"
          "SUPER, S, Scratchpad, togglespecialworkspace, scratch"
          "SUPER SHIFT, S, Move to scratchpad, movetoworkspace, special:scratch"
          "SUPER, mouse_down, Next workspace, workspace, e+1"
          "SUPER, mouse_up, Previous workspace, workspace, e-1"

          # Session
          "SUPER, escape, Power menu, exec, hypr-power-menu"
          "SUPER CTRL, L, Lock screen, exec, loginctl lock-session"
          "SUPER SHIFT, space, Toggle top bar, exec, pkill -SIGUSR1 waybar"

          # Screenshots (saved to ~/Pictures/Screenshots and copied)
          ", Print, Screenshot region, exec, hyprshot -m region -o ~/Pictures/Screenshots"
          "SHIFT, Print, Screenshot window, exec, hyprshot -m window -o ~/Pictures/Screenshots"
          "CTRL, Print, Screenshot screen, exec, hyprshot -m output -o ~/Pictures/Screenshots"
          "SUPER, Print, Colour picker, exec, hyprpicker -a"
        ] ++ workspaceBinds;

        bindmd = [
          "SUPER, mouse:272, Move window, movewindow"
          "SUPER, mouse:273, Resize window, resizewindow"
        ];

        # Repeat while held + work on the lock screen. SwayOSD draws the overlay.
        bindeld = [
          ", XF86AudioRaiseVolume, Volume up, exec, swayosd-client --output-volume raise"
          ", XF86AudioLowerVolume, Volume down, exec, swayosd-client --output-volume lower"
          ", XF86MonBrightnessUp, Brightness up, exec, swayosd-client --brightness raise"
          ", XF86MonBrightnessDown, Brightness down, exec, swayosd-client --brightness lower"
        ];
        bindld = [
          ", XF86AudioMute, Mute, exec, swayosd-client --output-volume mute-toggle"
          ", XF86AudioMicMute, Mute mic, exec, swayosd-client --input-volume mute-toggle"
          ", XF86AudioPlay, Play/pause, exec, playerctl play-pause"
          ", XF86AudioPause, Play/pause, exec, playerctl play-pause"
          ", XF86AudioNext, Next track, exec, playerctl next"
          ", XF86AudioPrev, Previous track, exec, playerctl previous"
        ];
      };
    };

    # --- Launcher: Walker + Elephant (Omarchy's launcher) ---
    services.elephant.enable = true;
    services.walker = {
      enable = true;
      systemd.enable = true;  # resident service → instant open
      settings = {
        close_when_open = true;
        force_keyboard_focus = true;
      };
      theme = {
        name = "desktop";
        style = ''
          @define-color window_bg_color #${c.bg};
          @define-color accent_bg_color #${c.overlay};
          @define-color theme_fg_color #${c.fg};
          @define-color error_bg_color #${c.red};
          @define-color error_fg_color #${c.fg};
        '' + builtins.readFile ./walker-style.css;
      };
    };
    # Both units hard-code graphical-session.target; rebind so they never start
    # under GNOME (which also reaches graphical-session.target).
    systemd.user.services.walker.Install.WantedBy = lib.mkForce [ sessionTarget ];
    systemd.user.services.elephant.Install.WantedBy = lib.mkForce [ sessionTarget ];
    systemd.user.services.elephant.Unit.PartOf = lib.mkForce [ sessionTarget ];

    # --- Top bar ---
    programs.waybar = {
      enable = true;
      systemd.enable = true;
      settings = [{
        layer = "top";
        position = "top";
        height = 26;
        spacing = 0;
        modules-left = [ "custom/menu" "hyprland/workspaces" ];
        modules-center = [ "clock" ];
        modules-right = [ "tray" "bluetooth" "network" "wireplumber" "cpu" "battery" "custom/power" ];

        "custom/menu" = {
          format = "";
          on-click = "walker";
          tooltip = false;
        };
        "hyprland/workspaces" = {
          on-click = "activate";
          format = "{icon}";
          format-icons = {
            default = "";
            active = "󱓻";
            "1" = "1"; "2" = "2"; "3" = "3"; "4" = "4"; "5" = "5";
            "6" = "6"; "7" = "7"; "8" = "8"; "9" = "9"; "10" = "0";
          };
          persistent-workspaces = { "1" = [ ]; "2" = [ ]; "3" = [ ]; "4" = [ ]; "5" = [ ]; };
        };
        clock = {
          format = "{:%A %I:%M %p}";
          format-alt = "{:%d %B W%V %Y}";
          tooltip = false;
        };
        cpu = {
          interval = 5;
          format = "󰍛";
          on-click = "${terminal} start -- btop";
        };
        network = {
          format-icons = [ "󰤯" "󰤟" "󰤢" "󰤥" "󰤨" ];
          format = "{icon}";
          format-wifi = "{icon}";
          format-ethernet = "󰀂";
          format-disconnected = "󰖪";
          tooltip-format-wifi = "{essid} ({frequency} GHz)\n⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-ethernet = "⇣{bandwidthDownBytes}  ⇡{bandwidthUpBytes}";
          tooltip-format-disconnected = "Disconnected";
          interval = 3;
          on-click = "nm-connection-editor";
        };
        battery = {
          interval = 5;
          format = "{capacity}% {icon}";
          format-discharging = "{icon}";
          format-charging = "{icon}";
          format-plugged = "";
          format-full = "󰂅";
          format-icons = {
            charging = [ "󰢜" "󰂆" "󰂇" "󰂈" "󰢝" "󰂉" "󰢞" "󰂊" "󰂋" "󰂅" ];
            default = [ "󰁺" "󰁻" "󰁼" "󰁽" "󰁾" "󰁿" "󰂀" "󰂁" "󰂂" "󰁹" ];
          };
          tooltip-format-discharging = "{power:>1.0f}W↓ {capacity}%";
          tooltip-format-charging = "{power:>1.0f}W↑ {capacity}%";
          states = { warning = 20; critical = 10; };
        };
        bluetooth = {
          format = "󰂯";
          format-disabled = "󰂲";
          format-connected = "󰂱";
          tooltip-format = "Devices connected: {num_connections}";
          on-click = "blueman-manager";
        };
        wireplumber = {
          format = "{icon}";
          format-icons = [ "" "" "" ];
          format-muted = "󰝟";
          scroll-step = 5;
          on-click = "pavucontrol";
          on-click-right = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
          tooltip-format = "Playing at {volume}%";
          max-volume = 150;
        };
        tray.spacing = 13;
        "custom/power" = {
          format = "󰐥";
          on-click = "hypr-power-menu";
          tooltip = false;
        };
      }];
      style = ''
        @define-color background #${c.bg};
        @define-color foreground #${c.fg};
        @define-color accent #${c.accent};
        @define-color urgent #${c.red};

        * {
          border: none;
          border-radius: 0;
          min-height: 0;
          font-family: "CaskaydiaMono Nerd Font";
          font-size: 14px;
          color: @foreground;
        }
        window#waybar { background-color: @background; }
        #custom-menu { margin-left: 10px; margin-right: 4px; color: @accent; }
        #workspaces { margin-left: 4px; }
        #workspaces button { all: initial; padding: 2px 6px; margin-right: 3px; }
        #workspaces button.active { color: @accent; }
        #workspaces button.urgent { color: @urgent; }
        #tray, #bluetooth, #network, #wireplumber, #cpu, #battery, #clock, #custom-power {
          min-width: 12px;
          margin-right: 13px;
        }
        #battery.warning { color: #${c.yellow}; }
        #battery.critical:not(.charging) { color: @urgent; }
        tooltip { padding: 2px; background-color: #${c.surface}; }
        tooltip label { padding: 2px; }
      '';
    };

    # --- Notifications ---
    services.mako = {
      enable = true;
      settings = {
        background-color = "#${c.bg}";
        text-color = "#${c.fg}";
        border-color = "#${c.accent}";
        progress-color = "over #${c.surface}";
        font = "CaskaydiaMono Nerd Font 11";
        width = 420;
        padding = "10";
        margin = "10";
        border-size = 2;
        border-radius = 4;
        anchor = "top-right";
        default-timeout = 5000;
        max-visible = 5;
        group-by = "app-name";
        "urgency=critical" = {
          border-color = "#${c.red}";
          default-timeout = 0;
        };
      };
    };

    # --- On-screen display for volume/brightness ---
    services.swayosd.enable = true;

    # --- Polkit agent (GNOME Shell provides one under GNOME; Hyprland needs its own) ---
    services.hyprpolkitagent.enable = true;

    # --- Lock + idle ---
    programs.hyprlock = {
      enable = true;
      settings = {
        general = {
          hide_cursor = true;
          ignore_empty_input = true;
        };
        background = [{
          monitor = "";
          color = rgb c.bg;
          path = if cfg.wallpaper != null then toString cfg.wallpaper else "";
          blur_passes = 3;
        }];
        input-field = [{
          monitor = "";
          size = "600, 100";
          position = "0, 0";
          halign = "center";
          valign = "center";
          inner_color = rgba c.surface "cc";
          outer_color = rgb c.accent;
          outline_thickness = 4;
          font_family = "CaskaydiaMono Nerd Font";
          font_color = rgb c.fg;
          placeholder_color = rgb c.muted;
          placeholder_text = "  Enter Password 󰈷 ";
          check_color = rgb c.green;
          fail_color = rgb c.red;
          fail_text = "Wrong";
          rounding = 0;
          shadow_passes = 0;
          fade_on_empty = false;
        }];
        label = [{
          monitor = "";
          text = "cmd[update:30000] date +'%A %-d %B  %-I:%M %p'";
          color = rgb c.fg;
          font_size = 24;
          font_family = "CaskaydiaMono Nerd Font";
          position = "0, 120";
          halign = "center";
          valign = "center";
        }];
      };
    };

    services.hypridle = {
      enable = true;
      settings = {
        general = {
          lock_cmd = "pidof hyprlock || hyprlock";
          before_sleep_cmd = "loginctl lock-session";
          after_sleep_cmd = "hyprctl dispatch dpms on";
        };
        listener = [
          { timeout = 300; on-timeout = "loginctl lock-session"; }
          { timeout = 330; on-timeout = "hyprctl dispatch dpms off"; on-resume = "hyprctl dispatch dpms on && brightnessctl -r"; }
        ];
      };
    };
  };
}
