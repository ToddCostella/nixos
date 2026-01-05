# Playwright Development Environment Setup

This NixOS module provides all system dependencies required for running Playwright E2E tests with Chromium browser.

## Installation

### 1. Import the module in your configuration.nix

Add the following to your `imports` section in `configuration.nix`:

```nix
imports = [
  ./hardware-configuration.nix
  ./esp32-dev.nix
  ./photo-restoration.nix
  ./desktop-icons.nix
  ./desktop-gnome.nix
  ./playwright-dev.nix  # Add this line
];
```

### 2. Apply the configuration

```bash
# Test the configuration first
sudo nixos-rebuild dry-build

# Apply the configuration
sudo nixos-rebuild switch
```

### 3. Install Playwright browsers in your project

In the Buoyancy Platform frontend directory:

```bash
cd /home/todd/dev/buoyancy-platform/frontend
npx playwright install chromium
```

## What's Included

The `playwright-dev.nix` module adds the following system dependencies to `nix-ld.libraries`:

### Core Browser Dependencies
- `glib` - Low-level core library
- `gobject-introspection` - Object introspection
- `nss`, `nspr` - Network Security Services

### Accessibility
- `atk` - Accessibility toolkit
- `at-spi2-atk`, `at-spi2-core` - Assistive Technology Service Provider Interface

### Display and Rendering
- `cups` - Printing support
- `dbus` - Message bus system
- `libdrm` - Direct Rendering Manager
- `expat` - XML parsing
- `libxcb`, `libxkbcommon` - X protocol C bindings

### X11 Libraries
- `libX11` - X11 client library
- `libXcomposite`, `libXdamage`, `libXext` - X11 extensions
- `libXfixes`, `libXrandr` - X11 fixes and rotation

### Graphics
- `mesa` - OpenGL implementation
- `libGL` - OpenGL library

### Font Rendering
- `pango` - Text rendering
- `cairo` - 2D graphics library

### Audio
- `alsa-lib` - Advanced Linux Sound Architecture

### GTK and Theming
- `gtk3` - GTK+ 3 toolkit
- `gdk-pixbuf` - Image loading library

### Utilities
- `curl`, `wget` - HTTP clients for browser downloads

## Running Playwright Tests

Once the configuration is applied and browsers are installed:

```bash
cd /home/todd/dev/buoyancy-platform/frontend

# Set library path (required until next rebuild)
export LD_LIBRARY_PATH=/run/current-system/sw/share/nix-ld/lib:$LD_LIBRARY_PATH

# Run all E2E tests
npx playwright test

# Run specific test file
npx playwright test interaction-panel.spec.ts

# Run with UI mode
npx playwright test --ui

# Run in headed mode (see the browser)
npx playwright test --headed

# Run with debugging
npx playwright test --debug
```

**Note:** After running `sudo nixos-rebuild switch`, the LD_LIBRARY_PATH export should not be necessary as libraries will be available system-wide via nix-ld.

## Troubleshooting

### Missing Libraries

If you get "missing library" errors after applying the configuration:

1. Check that the module is properly imported in `configuration.nix`
2. Verify the configuration was successfully applied:
   ```bash
   sudo nixos-rebuild switch
   ```
3. Check that nix-ld is enabled and includes the Playwright libraries:
   ```bash
   cat /etc/ld-nix.so.preload
   ```

### Browser Download Issues

If Playwright can't download browsers:

```bash
# Force reinstall
npx playwright install --force chromium

# Check installation
npx playwright install --dry-run
```

### Library Path Issues

The libraries are automatically added to the system via `nix-ld`, which makes them available to all dynamically linked executables including Node.js processes running Playwright.

You can verify the libraries are available:

```bash
# Check if libraries are in the nix-ld path
cat /etc/ld-nix.so.preload
```

## System Integration

This module integrates with your existing NixOS configuration by:

1. Adding Playwright dependencies to `programs.nix-ld.libraries`
2. Making libraries available to all processes without modifying `LD_LIBRARY_PATH`
3. Working seamlessly with your existing development tools (Node.js, npm, etc.)

## Benefits

- **Declarative**: All dependencies defined in code
- **Reproducible**: Same setup on any NixOS machine
- **System-wide**: Available to all projects that need Playwright
- **No conflicts**: Isolated from user-space packages
- **Automatic**: Libraries available without manual setup
- **Rollback-able**: Can revert with `sudo nixos-rebuild rollback`

## Updating

If Playwright updates its dependency requirements:

1. Update the package list in `playwright-dev.nix`
2. Test with `sudo nixos-rebuild dry-build`
3. Apply with `sudo nixos-rebuild switch`
4. Commit changes to git

## Optional: System-wide Playwright CLI

If you want the `playwright` command available system-wide, uncomment the following in `playwright-dev.nix`:

```nix
environment.systemPackages = with pkgs; [
  playwright-driver
];
```

Then rebuild:

```bash
sudo nixos-rebuild switch
```

This makes the Playwright CLI available globally, but is optional since most projects use the locally installed version via `npx`.

## Support

For issues with:
- **NixOS configuration**: See `/home/todd/nixos-config/README.md`
- **Playwright**: See https://playwright.dev/docs/intro
- **Buoyancy Platform**: See project documentation

## Related Files

- `configuration.nix` - Main system configuration
- `esp32-dev.nix` - ESP32 development environment
- `photo-restoration.nix` - Photo restoration tools
- `desktop-gnome.nix` - GNOME desktop environment
