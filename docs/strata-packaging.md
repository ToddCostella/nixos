# Packaging Strata (keyboard-first GTK4 file manager)

[Strata](https://github.com/lgse/strata) has no upstream Nix packaging, so we
build it from source. This note records why the derivation
(`pkgs/strata/default.nix`) looks the way it does, what is verified, and what to
check after the first real build.

## Where it lives

| Piece | Location |
|-------|----------|
| Flake input (pinned source) | `flake.nix` → `inputs.strata` (`github:lgse/strata/v1.0.0`, `flake = false`) |
| Derivation | `pkgs/strata/default.nix` (`rustPlatform.buildRustPackage`) |
| Wiring | `hosts/nixos-dev/desktop-tools.nix` → `environment.systemPackages` (`callPackage ../../pkgs/strata { src = inputs.strata; }`) + `bubblewrap` |

Because it is in the shared `desktop-tools.nix`, both `nixos-dev` and `vm-guest`
get it.

## Why it builds cleanly from source

- **Single crate**, edition 2024, and **every dependency in `Cargo.lock`
  resolves from crates.io** (no git deps). So `cargoLock.lockFile = src +
  "/Cargo.lock"` vendors fully offline — no `cargoHash`, no `outputHashes`.
- **Assets are compiled in**: icons/brand via GResource (`build.rs` →
  `glib-compile-resources`), and `math-renderer.js`, `themes/catalog.toml` and
  the bundled font via `include_str!`/`include_bytes!`. The installed package is
  therefore largely self-contained; we only install the desktop entry, icon,
  D-Bus services, portal files and an install-source marker alongside the binary.

## The sandbox (the interesting part)

Strata runs untrusted-input preview/extraction helpers inside a **bubblewrap**
jail (`src/sandbox*`). Upstream hard-codes FHS paths but exposes compile-time
overrides for non-FHS distros, which we set in the derivation's `env`:

| Knob | Value | Why |
|------|-------|-----|
| `STRATA_SANDBOX_ROOT` | `/nix/store` | Bound read-only in the jail so the bind-mounted helper binary's whole library closure resolves (there is no `/usr`). |
| `STRATA_SANDBOX_PRLIMIT` | `${util-linux}/bin/prlimit` | Upstream default `/usr/bin/prlimit` does not exist on NixOS. |
| `STRATA_SANDBOX_PATH` | `util-linux:imagemagick:ffmpeg` bins | `PATH` inside the (clearenv) jail. |
| `STRATA_SANDBOX_GDK_PIXBUF_MODULE_FILE` | gdk-pixbuf `loaders.cache` | Pixbuf loaders for in-jail image decode. |

`bwrap` itself is **not** hard-coded: strata's `trusted_command` resolver
searches `/run/current-system/sw/bin` + `/run/wrappers/bin` and trusts
`/nix/store`, so it finds our system-wide `bubblewrap`. That is why
`bubblewrap` is added to `environment.systemPackages` (not just to strata's
wrapper PATH — the resolver ignores the latter).

The install-source marker (`$out/share/strata/install-source.toml`,
`manager = "Nix"`) tells strata it is package-managed and **disables its
self-updater**, which would otherwise try to overwrite the read-only store.

## Verified vs. not

**Verified here (eval only):** the derivation evaluates to a `.drv`; all nixpkgs
deps resolve; `cargoLock` accepts every crate; the sandbox env knobs are baked
in. Flake parses and the module wiring is accepted.

**NOT yet verified (needs a real build on the machine):**

1. **The Rust compile** — fetches crates and compiles ~60 deps incl. the C/C++
   bits (`unrar_sys`, `rquickjs` via `bindgenHook`). Edition 2024 needs rustc ≥
   1.85 (fine on nixos-unstable).
2. **Launch + GTK wrapping** — `wrapGAppsHook4` env (GI typelibs, GSettings,
   GST plugins). We append the GStreamer plugin path and runtime helpers
   (ffmpeg, imagemagick, ffmpegthumbnailer, gvfs, udiskie, bubblewrap) in
   `preFixup`.
3. **The sandbox actually running** — unprivileged user namespaces must be
   enabled (NixOS default). Test an archive extraction and a video/image
   preview; if the jail fails, re-check the `STRATA_SANDBOX_*` values.

First build/apply:

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
strata            # launch
strata --version  # should print v1.0.0 / stable
```

## Known rough edges

- **SVG previews inside the jail**: `STRATA_SANDBOX_GDK_PIXBUF_MODULE_FILE`
  points at the base gdk-pixbuf cache (raster loaders). SVG thumbnailing in the
  sandbox may need a librsvg-merged loaders.cache; raster formats are unaffected.
- **xdg portal FileChooser backend**: the `.portal` + portal impl service are
  installed but **not** wired as the system default (so they can't clash with
  your current chooser). To opt in, add strata to `xdg.portal.extraPortals` and
  set the `org.freedesktop.impl.portal.FileChooser` preference.
- **`rar` support**: the default feature set includes `rar` (`unrar`/`unrar_sys`,
  which bundle the non-free UnRAR source). Build with
  `--no-default-features` (drop the `rar` feature) if you'd rather avoid it.
- **Desktop integration**: strata targets Omarchy/Hyprland. It runs fine under
  COSMIC (generic GTK4 Wayland), but "set as default file manager" and the
  `udiskie` encrypted-volume flow are manual.

## Updating

Bump the tag in `flake.nix` (`inputs.strata.url`), then:

```bash
nix flake update strata ~/nixos-config
sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev
```

If a future release adds a git dependency to `Cargo.lock`, add its hash under
`cargoLock.outputHashes` in `pkgs/strata/default.nix`.
