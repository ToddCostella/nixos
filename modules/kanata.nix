# kanata — QMK-style layers for the laptop's BUILT-IN keyboard.
#
# Why this exists: the Dygma Defy does all of this in its own firmware, but the
# XPS 17's built-in keyboard is driven by Dell's embedded controller and cannot
# be reflashed (QMK is a non-starter — it only runs on a keyboard's own MCU).
# kanata is the software equivalent: it grabs the evdev device, remaps at the
# input layer, and replays through uinput, so it works in the TTY, under
# COSMIC/Wayland and under GNOME alike.
#
# This config MIRRORS the Defy layout so muscle memory carries over, with one
# deliberate divergence: the home-row mods here are the standard GACS order
# (Super/Alt/Ctrl/Shift) rather than the Defy's current
# Super/Alt-less/Ctrl/Super assignment, which had drifted to four Supers and no
# Alt. Re-sync Bazecor to GACS and the two match again.
#
# Source of truth for the mirrored layout:
#   ~/Dygma/Backups/Defy/f3ae0a44d7306e80/20261016122334-Defy.json
#
# SCOPE: deliberately targets ONLY the i8042 (built-in) keyboard. The Defy is a
# USB device on a different path, so it is never intercepted and keeps its own
# firmware behaviour — plug it in and nothing here applies to it.
{ ... }:

{
  services.kanata = {
    enable = true;

    keyboards.builtin = {
      # The built-in keyboard is on the legacy i8042 controller, NOT USB, so
      # this by-path name is stable across reboots and port changes. Do NOT use
      # a bare /dev/input/eventN — those renumber.
      #
      # Listing the device explicitly (rather than letting kanata grab every
      # keyboard) is what keeps the Defy out of scope.
      devices = [ "/dev/input/by-path/platform-i8042-serio-0-event-kbd" ];

      extraDefCfg = ''
        ;; Let other processes see the keys too; without this some Wayland
        ;; compositors lose track of modifier state.
        process-unmapped-keys yes
      '';

      config = ''
        ;; ---------------------------------------------------------------
        ;; Source: the physical keys this config takes over. Anything not
        ;; listed here passes through untouched.
        ;; ---------------------------------------------------------------
        (defsrc
          esc  f1   f2   f3   f4   f5   f6   f7   f8   f9   f10  f11  f12
          grv  1    2    3    4    5    6    7    8    9    0    -    =    bspc
          tab  q    w    e    r    t    y    u    i    o    p    [    ]    \
          caps a    s    d    f    g    h    j    k    l    ;    '    ret
          lsft z    x    c    v    b    n    m    ,    .    /    rsft
          lctl lmet lalt           spc            ralt rmet rctl
        )

        ;; ---------------------------------------------------------------
        ;; Timings — matched to the Defy so the two keyboards feel the same.
        ;; From the backup (20261023144832-Defy.json):
        ;;   superkeys.holdstart    = 353   <- the one that matters here
        ;;   superkeys.timeout      = 318
        ;;   qukeys.holdTimeout     = 207
        ;;   overlap/overlapThreshold ~ 85-90
        ;;
        ;; The Defy home row is built from SUPERKEYS (SK1-SK8), not qukeys, so
        ;; superkeys.holdstart is what governs how long a hold takes to engage
        ;; there. hold-time was originally set to 210 from qukeys.holdTimeout —
        ;; the wrong field — which made the laptop fire modifiers ~143ms sooner
        ;; than the Defy and tripped home-row mods during normal typing.
        ;; Raised to 353 on 2026-10-25 to match.
        ;;
        ;; tap-time  = how long a press can last and still count as a tap
        ;; hold-time = how long to hold before the modifier engages
        ;;
        ;; NOTE: tap-time and hold-time are currently UNREFERENCED, because
        ;; the home-row mods below are disabled. Kept so re-enabling a key is
        ;; a one-line change. The layer-* vars below ARE still live.
        ;; ---------------------------------------------------------------
        (defvar
          tap-time 200
          hold-time 353

          ;; Thumb layer keys engage faster than the home-row mods; a layer
          ;; shift is a deliberate motion, not something you trip over while
          ;; typing a word.
          layer-tap-time 200
          layer-hold-time 150
        )

        ;; ---------------------------------------------------------------
        ;; HOME-ROW MODS ARE DISABLED (2026-10-27).
        ;;
        ;; They misfired during ordinary typing and three attempts failed to
        ;; fix it, so the home row is plain letters for now. The nav/audio
        ;; layers and caps-as-esc are unaffected and still work.
        ;;
        ;; Use the real modifier keys (lctl/lalt/lmet/lsft) meanwhile. The
        ;; Defy keeps its own superkey home-row mods; only the laptop is
        ;; affected by this file.
        ;;
        ;; WHAT WAS TRIED, so it is not repeated:
        ;;
        ;;  1. tap-hold-release, 200/210 — original. Misfired.
        ;;  2. tap-hold-release, 200/353 — raised the timeout to match the
        ;;     Defy's superkeys.holdstart. Still misfired, because
        ;;     tap-hold-release resolves hold EARLY when another key is
        ;;     pressed and released (which is what typing a roll does), so
        ;;     the timeout is never consulted on that path.
        ;;  3. tap-hold-opposite-hand + defhands + (require-prior-idle 150),
        ;;     kanata's own recommended HRM setup. Reported as WORSE, with
        ;;     modifiers still misfiring while typing.
        ;;
        ;; (3) failing the same way as (1) and (2) is the useful clue: all
        ;; three resolve differently, so the problem may not be the hold
        ;; mechanism at all. Things not yet ruled out:
        ;;   - COSMIC/libinput seeing both the real and the kanata virtual
        ;;     device, so the OS applies its own repeat/modifier handling on
        ;;     top (check: `kanata --debug` against what the compositor gets)
        ;;   - the Linux antecedent-key-repeat issue the kanata docs warn
        ;;     about for ALL tap-hold variants, whose workaround is wrapping
        ;;     the action in (multi f24 (tap-hold ...)) — see kanata
        ;;     discussion #422. This was never tried.
        ;;
        ;; To re-enable a single key for testing, give it back a tap-hold
        ;; form; the deflayer already points at these aliases.
        ;; ---------------------------------------------------------------
        (defalias
          ;; left hand — plain letters while HRM is disabled
          hm-a a
          hm-s s
          hm-d d
          hm-f f

          ;; right hand — plain letters while HRM is disabled
          hm-j j
          hm-k k
          hm-l l
          hm-; ;

          ;; Thumb/hand layer access. The Defy reaches Navigation and Audio
          ;; from the thumb cluster; the laptop has no thumb keys to spare, so
          ;; these ride on the keys nearest to hand:
          ;;
          ;;   caps  tap -> esc        hold -> Navigation   (layer 1 on Defy)
          ;;   ralt  tap -> ralt       hold -> Audio/Fn     (layer 2 on Defy)
          ;;
          ;; caps-as-esc is worth having on its own; the Defy puts esc on the
          ;; top-left too.
          nav  (tap-hold $layer-tap-time $layer-hold-time esc  (layer-while-held navigation))
          fnl  (tap-hold $layer-tap-time $layer-hold-time ralt (layer-while-held audio))
        )

        ;; ---------------------------------------------------------------
        ;; Base layer — unchanged QWERTY plus the home-row mods.
        ;; ---------------------------------------------------------------
        (deflayer base
          esc   f1    f2    f3    f4    f5    f6    f7    f8    f9    f10   f11   f12
          grv   1     2     3     4     5     6     7     8     9     0     -     =     bspc
          tab   q     w     e     r     t     y     u     i     o     p     [     ]     \
          @nav  @hm-a @hm-s @hm-d @hm-f g     h     @hm-j @hm-k @hm-l @hm-; '     ret
          lsft  z     x     c     v     b     n     m     ,     .     /     rsft
          lctl  lmet  lalt              spc               @fnl  rmet  rctl
        )

        ;; ---------------------------------------------------------------
        ;; Navigation — mirrors the Defy's layer 1.
        ;;
        ;; Left hand keeps the Defy's arrow/paging block in the same physical
        ;; spots: w/e/r = home/up/end on the upper row, s/d/f = left/down/right
        ;; on the home row. Right hand carries the numpad, as on the Defy.
        ;; ---------------------------------------------------------------
        (deflayer navigation
          esc   f1    f2    f3    f4    f5    f6    f7    f8    f9    f10   f11   f12
          grv   1     2     3     4     5     nlck kp/   kp*   kp-   =     -     =     bspc
          tab   _     home  up    end   pgup  _     kp7   kp8   kp9   kp+   [     ]     \
          _     prnt  left  down  rght  pgdn  _     kp4   kp5   kp6   kprt  '     ret
          lsft  _     _     _     _     _     kp.   kp1   kp2   kp3   kp0   rsft
          lctl  lmet  lalt              spc               _     rmet  rctl
        )

        ;; ---------------------------------------------------------------
        ;; Audio / function — mirrors the Defy's layer 2 (named "Audio").
        ;;
        ;; On the Defy this layer puts F-keys on the number row and transport
        ;; controls under the left hand: e = next, r = play, t = volume up,
        ;; w/x region = prev/stop, f = volume down.
        ;; ---------------------------------------------------------------
        (deflayer audio
          grv   f1    f2    f3    f4    f5    f6    f7    f8    f9    f10   f11   f12
          grv   f1    f2    f3    f4    f5    f6    f7    f8    f9    f10   f11   f12   bspc
          tab   _     _     next  pp    vold  _     _     _     _     _     [     ]     \
          _     _     prev  pp    next  volu  _     _     _     _     _     '     ret
          lsft  _     _     mute  _     _     _     _     brdn  brup  _     rsft
          lctl  lmet  lalt              spc               _     rmet  rctl
        )
      '';
    };
  };
}
