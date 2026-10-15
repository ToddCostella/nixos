# Strata — a fast, keyboard-first GTK4 file manager ("Navigate every layer").
# Upstream: https://github.com/lgse/strata  (MIT)
#
# There is no upstream Nix packaging, so this is a from-source
# `rustPlatform.buildRustPackage`. `src` is the pinned `strata` flake input
# (flake = false) passed in from the host module; everything else is filled by
# callPackage. See docs/strata-packaging.md for the full rationale.
#
# Why this builds cleanly from source:
#   * Single crate (no workspace), edition 2024, and every dependency in
#     Cargo.lock resolves from crates.io (no git deps) — so `cargoLock.lockFile`
#     vendors fully offline, no cargoHash needed.
#   * Icons, brand assets, the theme catalog, the math-renderer JS and the
#     bundled font are all compiled into the binary (GResource + include_str!/
#     include_bytes!), so the installed package is largely self-contained.
#
# The interesting part is the preview SANDBOX. Strata runs untrusted-input
# preview/extraction helpers inside a bubblewrap jail. Upstream hard-codes
# FHS paths (/usr, /usr/bin/prlimit, …) but exposes compile-time overrides for
# exactly the non-FHS case. We point them at the Nix store:
#   * bwrap itself is located at runtime by strata's own `trusted_command`
#     resolver, which already searches /run/current-system/sw/bin +
#     /run/wrappers/bin and trusts /nix/store — so NixOS is a first-class target
#     as long as `bubblewrap` is installed system-wide (it is; see the host
#     module). We also put it on strata's PATH for good measure.
#   * STRATA_SANDBOX_ROOT=/nix/store binds the store read-only inside the jail so
#     the bind-mounted helper binary's full library closure resolves.
#   * STRATA_SANDBOX_PRLIMIT / _PATH / _GDK_PIXBUF_MODULE_FILE point at store
#     paths that exist inside that bound root.
{
  lib,
  rustPlatform,
  src,
  # native
  pkg-config,
  wrapGAppsHook4,
  glib, # glib-compile-resources (build.rs) + gio
  gobject-introspection,
  # gtk / rendering stack
  gtk4,
  gtksourceview5,
  poppler, # poppler-glib (poppler-rs)
  gdk-pixbuf,
  graphene,
  cairo,
  pango,
  librsvg, # SVG gdk-pixbuf loader (icons / previews)
  fontconfig,
  wayland,
  # media preview
  gst_all_1,
  ffmpeg,
  ffmpegthumbnailer,
  imagemagick,
  # sandbox + runtime helpers
  bubblewrap,
  util-linux, # prlimit
  gvfs, # trash / mounts / network locations
  udiskie, # optional: encrypted-volume unlock
}:

let
  version = "1.0.0";

  # GStreamer plugin set for in-sandbox media thumbnailing/preview.
  gstPlugins = with gst_all_1; [
    gstreamer
    gst-plugins-base
    gst-plugins-good
    gst-plugins-bad
    gst-plugins-ugly
    gst-libav
  ];

  # PATH made available INSIDE the bubblewrap jail. The helper is strata itself
  # (`/app/strata --preview-helper`) plus the occasional convert/ffmpeg exec;
  # all live under /nix/store, which STRATA_SANDBOX_ROOT binds read-only.
  sandboxPath = lib.makeBinPath [
    util-linux
    imagemagick
    ffmpeg
  ];

  # gdk-pixbuf loader cache used inside the jail (cleared env → must be absolute).
  # Base raster loaders; SVG-in-sandbox fidelity may want a librsvg-merged cache
  # (see docs/strata-packaging.md "Known rough edges").
  pixbufModuleFile = "${gdk-pixbuf}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache";
in
rustPlatform.buildRustPackage {
  pname = "strata";
  inherit version src;

  cargoLock = {
    lockFile = src + "/Cargo.lock";
  };

  # Pin the version strings build.rs would otherwise derive from a git checkout
  # (there is none in the Nix sandbox) so the About dialog is reproducible.
  env = {
    STRATA_RELEASE_TAG = "v${version}";
    STRATA_BUILD_KIND = "stable";
    # Derived from the locked input rather than hardcoded: `git ls-remote`
    # for an annotated tag returns the TAG OBJECT's hash (cf961328e114 for
    # v1.0.0), not the commit it points at. The flake locks the commit
    # (refs/tags/v1.0.0^{} = 0a086aa3bdb2), which is what was actually built,
    # so hardcoding the tag hash made the About dialog cite a dead ref.
    # Reading src.rev also means a version bump cannot leave this stale.
    STRATA_BUILD_COMMIT = builtins.substring 0 12 src.rev;

    # --- sandbox portability (see header) ---
    STRATA_SANDBOX_ROOT = "/nix/store";
    STRATA_SANDBOX_PATH = sandboxPath;
    STRATA_SANDBOX_PRLIMIT = "${util-linux}/bin/prlimit";
    STRATA_SANDBOX_GDK_PIXBUF_MODULE_FILE = pixbufModuleFile;
  };

  nativeBuildInputs = [
    pkg-config
    glib # glib-compile-resources for build.rs
    gobject-introspection
    wrapGAppsHook4
    rustPlatform.bindgenHook # rquickjs-sys / unrar_sys C bindings
  ];

  buildInputs = [
    glib
    gtk4
    gtksourceview5
    poppler
    gdk-pixbuf
    graphene
    cairo
    pango
    librsvg
    fontconfig
    wayland
  ]
  ++ gstPlugins;

  # The large test suite needs a display server, real filesystems and network;
  # it is not meaningful to run inside the Nix build sandbox.
  doCheck = false;

  postInstall = ''
    # Desktop entry (patch Exec to the absolute binary).
    install -Dm644 data/io.github.lgse.Strata.desktop \
      $out/share/applications/io.github.lgse.Strata.desktop
    substituteInPlace $out/share/applications/io.github.lgse.Strata.desktop \
      --replace-fail "Exec=strata" "Exec=$out/bin/strata"

    # App icon.
    install -Dm644 data/icons/scalable/apps/io.github.lgse.Strata.svg \
      $out/share/icons/hicolor/scalable/apps/io.github.lgse.Strata.svg

    # org.freedesktop.FileManager1 D-Bus service ("Open file location").
    install -Dm644 data/io.github.lgse.Strata.FileManager1.service \
      $out/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service
    substituteInPlace $out/share/dbus-1/services/io.github.lgse.Strata.FileManager1.service \
      --replace-fail "/usr/bin/strata" "$out/bin/strata"

    # xdg-desktop-portal FileChooser backend (installed but not wired as the
    # system default — see docs/strata-packaging.md to opt in via xdg.portal).
    install -Dm644 data/portal/strata.portal \
      $out/share/xdg-desktop-portal/portals/strata.portal
    install -Dm644 data/portal/org.freedesktop.impl.portal.desktop.strata.service.in \
      $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service
    substituteInPlace $out/share/dbus-1/services/org.freedesktop.impl.portal.desktop.strata.service \
      --replace-fail "@STRATA_EXECUTABLE@" "$out/bin/strata"

    # Bundled example action scripts (optional feature; strata reads these from
    # share/strata/actions unless STRATA_ACTION_DIR overrides).
    if [ -d data/actions ]; then
      mkdir -p $out/share/strata/actions
      cp -r data/actions/. $out/share/strata/actions/
    fi

    # install-source marker: tells strata it is package-managed and DISABLES its
    # self-updater (which would otherwise try to overwrite the read-only store).
    install -Dm644 /dev/stdin $out/share/strata/install-source.toml <<'EOF'
    manager = "Nix"
    package = "strata"
    channel = "stable"
    update_command = "sudo nixos-rebuild switch --flake ~/nixos-config#nixos-dev"
    EOF
  '';

  # Append runtime helpers to the wrapped binary's PATH + GStreamer plugin path.
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${
        lib.makeBinPath [
          bubblewrap
          util-linux
          ffmpeg
          ffmpegthumbnailer
          imagemagick
          gvfs
          udiskie
        ]
      }
      --prefix GST_PLUGIN_SYSTEM_PATH_1_0 : "${lib.makeSearchPath "lib/gstreamer-1.0" gstPlugins}"
    )
  '';

  meta = {
    description = "Fast, keyboard-first GTK4 file manager (Miller columns, fuzzy search, previews)";
    homepage = "https://github.com/lgse/strata";
    license = lib.licenses.mit;
    mainProgram = "strata";
    platforms = lib.platforms.linux;
  };
}
