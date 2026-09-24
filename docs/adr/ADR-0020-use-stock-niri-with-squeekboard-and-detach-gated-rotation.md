# ADR-0020: Use stock niri with squeekboard and detach-gated rotation for tablet use

- Status: Accepted
- Date: 2026-09-24

## Context

The 2025 ROG Flow Z13 (GZ302EA) is a tablet with a detachable keyboard
cover. With the cover detached the desktop has to work by touch alone: text
input without a keyboard, a way to reach the niri overview, and a screen that
follows the device orientation. With the cover attached it is a laptop and
the screen must stay upright whatever the accelerometer reports.

Stock niri 26.04 already handles touch input on the panel and maps it through
the output transform, but it has no touch gestures, no on-screen keyboard,
and no automatic rotation. The user is not in the `input` group and should
not be; the Z13's event devices are `root:input`.

Detaching the cover disconnects its USB device (`0b05:1a30`,
`GZ302EA-Keyboard`); the kernel log on this machine shows a `USB disconnect`
of that device and a fresh enumeration when it is attached again. sysfs and
`udevadm monitor` expose that to an unprivileged user. The `Asus WMI hotkeys`
device also advertises `SW_TABLET_MODE`, but whether it changes on a detach
is unverified.

## Decision

1. Stay on the stock, packaged niri. Tablet navigation is tap-based: a long
   press on the `dotfilesLauncher` pill or the `dotfilesWorkspaces` strip
   toggles the niri overview, next to the existing right click.
2. Detect "keyboard detached" from the presence of the cover's USB device,
   through the `tablet-mode` helper: `tablet-mode status` reads sysfs, and
   `tablet-mode watch` re-reads it on each `udevadm monitor` USB event. It
   only ever reports `tablet` on a GZ302 Flow Z13. Both the rotation service
   and the bar consume this one helper.
3. Rotate with a repository-owned `auto-rotate` user service, started with
   `niri.service`, that combines `monitor-sensor` (iio-sensor-proxy) and
   `tablet-mode watch` and applies `niri msg output <eDP> transform`. With the
   keyboard attached it forces `normal`; with it detached it follows the
   sensor unless a rotation lock, kept in
   `$XDG_STATE_HOME/dotfiles/rotation-lock`, is on. The dashboard gets a
   rotation-lock tile.
4. Use squeekboard from the official repositories as the on-screen keyboard,
   started with `niri.service` through its packaged `mobi.phosh.OSK.service`
   and a drop-in that orders it after niri. A new `dotfilesKeyboard` bar
   widget, shown only while the keyboard is detached, toggles its
   `sm.puri.OSK0` `Visible` state through the `osk` helper.

## Consequences

- No patched compositor: niri, the greeter's niri, and their updates stay on
  the packaged builds. Nothing in niri's `input`, `output`, `cursor`, or
  `debug` sections changes, so the greeter needs no re-sync for this.
- Rotation uses niri's temporary output configuration. A change to the
  output section of the config file resets it until the next sensor event.
- The detection relies on the cover appearing as that USB id. Another cover
  or firmware that keeps the device present needs a different
  `TABLET_MODE_KEYBOARD_ID` or another signal; the helper is the one place to
  change it.
- Touch gestures (edge swipes, multi-finger swipes) are not available; the
  overview, workspaces, and apps are reached by tapping and long-pressing the
  bar.
- squeekboard runs for the whole session, hidden until asked. It holds the
  seat's input-method slot, so another input method (fcitx, ibus) cannot run
  alongside it.
- Two small `udevadm monitor` processes run per session (rotation service and
  bar widget); both are idle until a USB event.

## Alternatives considered

- **niri-tablet** (<https://github.com/GGEZUS/niri-tablet>): a patched niri
  fork with touch gestures and tablet features. It needs a patched niri build
  pinned against package updates with `IgnorePkg`, and it would also replace
  the niri the greeter runs (`docs/greeter.md`). Rejected to keep the
  compositor on the packaged release.
- **lisgd**: a touch-gesture daemon that reads the touchscreen's evdev device
  directly. It needs read access to `/dev/input` (the `input` group), and it
  snoops the touches instead of consuming them, so every gesture also reaches
  the application under the finger. Rejected.
- **niri `switch-events` on `tablet-mode-on`/`tablet-mode-off`**: rootless and
  event-driven, but it depends on the `Asus WMI hotkeys` switch actually
  reporting `SW_TABLET_MODE` on a detach, which is unverified, and it fires
  only on changes, so a helper would still need the initial state. Kept as a
  fallback if the USB signal turns out to be unreliable.
- **Rotation driven by the sensor alone**: rotates the laptop when it is on a
  lap or tilted, which is exactly what attached use must not do.
