# Desktop Environment Configuration Guide

This NixOS configuration supports multiple desktop environments that can be easily enabled, disabled, or switched between at login time.

## Available Desktop Environments

1. **GNOME** - Modern, clean desktop environment (currently active)
2. **KDE Plasma 6** - Feature-rich, highly customizable desktop (disabled)
3. **Cinnamon** - Traditional desktop with modern features (disabled)

## Current Configuration

Only **GNOME** is currently enabled. The KDE and Cinnamon modules exist but are commented out in `configuration.nix`.

### GNOME Extensions
- **Forge** - Tiling window manager (requires GNOME 48 or earlier)
- **Workspace Indicator** - Shows current workspace
- **Just Perfection** - GNOME customization

## Enabling/Disabling Desktop Environments

To enable or disable a desktop environment, edit `/etc/nixos/configuration.nix`:

### Current Setup (All Enabled)
```nix
imports = [
  # ...
  ./desktop-gnome.nix     # GNOME Desktop
  ./desktop-kde.nix       # KDE Plasma 6 Desktop
  ./desktop-cinnamon.nix  # Cinnamon Desktop
  ./desktop-multi-de-compat.nix  # Required for multi-DE support
];
```

### Example: Only GNOME
```nix
imports = [
  # ...
  ./desktop-gnome.nix     # GNOME Desktop
  # ./desktop-kde.nix     # KDE Plasma 6 Desktop (disabled)
  # ./desktop-cinnamon.nix  # Cinnamon Desktop (disabled)
  # ./desktop-multi-de-compat.nix  # Not needed with single DE
];
```

### Example: GNOME and KDE Only
```nix
imports = [
  # ...
  ./desktop-gnome.nix     # GNOME Desktop
  ./desktop-kde.nix       # KDE Plasma 6 Desktop
  # ./desktop-cinnamon.nix  # Cinnamon Desktop (disabled)
  ./desktop-multi-de-compat.nix  # Required for multi-DE support
];
```

## Important Notes

1. **Multi-DE Compatibility Module**: When enabling multiple desktop environments, you MUST include `./desktop-multi-de-compat.nix` in your imports. This module resolves conflicts between desktop environments (like gsettings paths and SSH askpass programs).

2. **Applying Changes**: After modifying the configuration, apply changes with:
   ```bash
   sudo nixos-rebuild switch
   ```

3. **Testing Changes**: Before applying, test for syntax errors:
   ```bash
   sudo nixos-rebuild dry-build
   ```

4. **Logout Required**: After rebuilding, log out and back in to see the new desktop environment options at the login screen.

## Desktop Environment Features

### GNOME
- **File Manager**: Nautilus
- **Terminal**: Wezterm (default)
- **Text Editor**: gedit (via GNOME core apps)
- **Extensions**: Forge, Workspace Indicator, Just Perfection
- **Screenshot Tool**: gnome-screenshot
- **Utilities**: GNOME Tweaks, LibreOffice, Pika Backup

### KDE Plasma 6
- **File Manager**: Dolphin
- **Terminal**: Wezterm (default), Konsole (backup)
- **Text Editor**: Kate
- **Screenshot Tool**: Spectacle
- **Document Viewer**: Okular
- **Image Viewer**: Gwenview
- **Archive Manager**: Ark
- **Utilities**: Partition Manager, Color Chooser

### Cinnamon
- **File Manager**: Nemo
- **Terminal**: Wezterm (default), GNOME Terminal (backup)
- **Text Editor**: Xed
- **Image Viewer**: Xviewer
- **Document Viewer**: Xreader
- **Photo Organizer**: Pix
- **Calculator**: GNOME Calculator

## Terminal Configuration

All desktop environments are configured to use **Wezterm** as the default terminal emulator. You can:
- Press `Ctrl+Alt+T` (if keyboard shortcut is configured) to launch Wezterm
- Right-click on the desktop or in file managers and select "Open Terminal Here" to launch Wezterm
- Use application launchers to search for "Wezterm"

The native terminals (GNOME Terminal, Konsole) are kept as backup options and can still be launched manually if needed.

## Troubleshooting

### Desktop Environment Not Appearing at Login
1. Make sure you've run `sudo nixos-rebuild switch` after editing the configuration
2. Log out completely (not just lock screen)
3. Check the gear icon at the login screen - some themes make it subtle

### Settings Not Persisting Between Desktop Environments
This is normal - each desktop environment has its own settings. Your files and applications will work across all DEs, but themes, wallpapers, and DE-specific settings are separate.

### Conflicts Between Desktop Environments
The `desktop-multi-de-compat.nix` module handles most conflicts automatically. If you encounter issues:
1. Make sure `desktop-multi-de-compat.nix` is imported AFTER all desktop environment modules
2. Check that you haven't manually set conflicting options in `configuration.nix`

## Removing a Desktop Environment

To completely remove a desktop environment:

1. Comment out or remove its import line from `configuration.nix`
2. Run `sudo nixos-rebuild switch`
3. (Optional) Run garbage collection to free up space:
   ```bash
   sudo nix-collect-garbage -d
   ```

## Display Manager

All desktop environments use GDM (GNOME Display Manager) as the login screen. GDM is configured in the main `configuration.nix` and works well with all three desktop environments.
