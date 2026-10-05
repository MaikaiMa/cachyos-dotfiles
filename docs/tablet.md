# Tablet use on the Z13

With the keyboard cover detached, the 2025 ROG Flow Z13 is used by touch on
stock niri: the screen follows the device orientation, an on-screen keyboard
is one tap away in the bar, and a long press on the bar opens the niri
overview. With the cover attached nothing changes compared with laptop use.
[ADR-0020](adr/ADR-0020-use-stock-niri-with-squeekboard-and-detach-gated-rotation.md)
records the approach and the rejected alternatives.

## What is deployed

| Piece | Where | What it does |
| --- | --- | --- |
| `tablet-mode` | `chezmoi/dot_local/bin/executable_tablet-mode` | Reports `tablet` while the keyboard is detached, else `laptop`. |
| `auto-rotate` | `chezmoi/dot_local/bin/executable_auto-rotate` | Rotates the internal panel with the accelerometer while detached; holds the rotation lock. |
| `auto-rotate.service` | `chezmoi/dot_config/systemd/user/` | Runs `auto-rotate run` with the niri session. |
| `osk` | `chezmoi/dot_local/bin/executable_osk` | Shows, hides, or toggles squeekboard over D-Bus. |
| squeekboard drop-in | `chezmoi/dot_config/systemd/user/mobi.phosh.OSK.service.d/niri.conf` | Starts the packaged squeekboard unit after niri and stops it with the session. |
| Keyboard button | own bar, right island (`services/Tablet.qml`) | Shown only while the cover is detached; a tap toggles squeekboard. |
| Rotation lock tile | own bar, Settings panel (`Mod+S`) | Shown only while the cover is detached, next to Bluetooth as an icon; a tap toggles the lock. |
| Long press | own bar, left island (workspace pills and app icons) | Toggles the niri overview. |

Both units are enabled through chezmoi-managed links in
`niri.service.wants/`, like `dms.service`. None of this touches niri's
`input`, `output`, `cursor`, or `debug` sections, so the greeter does not need
a re-sync.

## Setting it up

Install the packages recorded in `packages/pacman.txt` (`squeekboard` is new;
`iio-sensor-proxy` is already present as a dependency and is now recorded
explicitly):

```fish
sudo pacman -S --needed squeekboard iio-sensor-proxy
./scripts/check-packages.sh --mark-explicit
```

Deploy the dotfiles, which include the own bar with the keyboard button:

```fish
./scripts/bootstrap.sh
```

The units start with the next login. To start them in the running session:

```fish
systemctl --user daemon-reload
systemctl --user start auto-rotate.service mobi.phosh.OSK.service
```

## Keyboard detection

Detaching the cover disconnects its USB device, vendor `0b05` product `1a30`
(`GZ302EA-Keyboard`); attaching it enumerates the device again. `tablet-mode`
looks for that id under `/sys/bus/usb/devices` and watches
`udevadm monitor --udev --subsystem-match=usb` for changes, both without extra
privileges. It only reports `tablet` on a GZ302 Flow Z13, so other hardware
always reads as `laptop`. A detach is trusted after one second, because USB
devices briefly disappear while resuming from suspend.

Check the current state, or watch it change while detaching:

```fish
tablet-mode status
tablet-mode watch
```

This was verified on the machine from the kernel log: a detach logs
`usb 3-4: USB disconnect`, and the re-attach enumerates `idVendor=0b05,
idProduct=1a30` again. The live `watch` transition itself has not been
observed with a physical detach yet. If a different cover or firmware shows
up under another id, set it for both consumers in
`~/.config/environment.d/` as `TABLET_MODE_KEYBOARD_ID=vvvv:pppp` (find it
with `lsusb`) and log in again.

The `Asus WMI hotkeys` device also advertises a tablet-mode switch, which
niri could act on with `switch-events { tablet-mode-on { … } }`. It reads as
off with the cover attached; whether it flips on a detach is untested, so it
is not used. See ADR-0020.

## Rotation

`auto-rotate.service` reads the accelerometer through `monitor-sensor
--accel` and sets the transform of the first `eDP-*` output (set
`AUTO_ROTATE_OUTPUT` to override):

| Keyboard | Rotation lock | Panel |
| --- | --- | --- |
| attached | any | `normal`, sensor ignored |
| detached | off | follows the sensor |
| detached | on | stays as it is |

The lock is the rotation lock tile in the Settings panel (`Mod+S`,
shown while the cover is detached), or from a terminal:

```fish
auto-rotate lock toggle
auto-rotate lock status
```

It is stored in `~/.local/state/dotfiles/rotation-lock` and survives a reboot.

The orientation-to-transform mapping lives in `transform_for_orientation` in
`auto-rotate`: `left-up` → `90`, `bottom-up` → `180`, `right-up` → `270`,
following iio-sensor-proxy's "this screen edge points up" names and niri's
counter-clockwise transforms. It is derived from those definitions, not yet
checked in every orientation on the device. If the picture ends up upside
down or mirrored in portrait, swap `90` and `270` there. Follow the service
and the raw sensor, each in its own terminal, while turning the device:

```fish
journalctl --user -fu auto-rotate.service
monitor-sensor --accel
```

niri maps the touchscreen through the output transform, so touches should
land where they are drawn after a rotation; this is untested on the device.
`input.kdl` has no `touch { map-to-output }`, so niri picks the touchscreen's
output itself; with an external display connected, setting it to the panel
may be needed. That is a change to the `input` section and needs
`./scripts/setup-greetd.sh` afterwards.

Rotation uses niri's temporary output configuration: editing the output
section of the niri config resets the panel to `normal` until the next
orientation change.

## On-screen keyboard

squeekboard runs for the whole session through its packaged
`mobi.phosh.OSK.service` and stays hidden until asked. The keyboard button in
the bar appears only while the cover is detached; a tap toggles squeekboard,
and re-attaching the cover hides it. From a terminal:

```fish
osk toggle
osk status
osk watch
```

`osk` calls `SetVisible` on squeekboard's `sm.puri.OSK0` D-Bus interface and
starts the unit when it is not running. `osk watch` follows the `Visible`
property with `gdbus monitor` (squeekboard emits `PropertiesChanged` for it,
checked on the device) and reports `hidden` when squeekboard stops; the bar
button uses it to show `keyboard_hide` in the primary colour while the
keyboard is on screen. The bar runs `tablet-mode watch` all the time and
`osk watch` only while the cover is detached; both are started again 5 s
after they exit.

squeekboard also shows itself when a text field gains focus, but only when
GNOME's screen-keyboard setting is on. That setting is not managed: turning it
on also pops the keyboard up while the cover is attached. To try it:

```fish
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
```

Which applications trigger that depends on their support for the
`text-input-v3` protocol; GTK and Qt applications do, many others do not.

## Overview by long press

A 500 ms long press on a workspace dot or an app icon in the own bar's left
island toggles the niri overview; a normal tap keeps its own action. See
"Left island" in [shell.md](shell.md).

## Power key and suspend

niri suspends again on the power-key press that wakes the system
([niri-wm/niri#2233](https://github.com/niri-wm/niri/issues/2233)). With the
keyboard detached the power button is the only way to wake the Z13, so it
looped straight back into suspend. niri's power-key handling is therefore
disabled in `cfg/input.kdl`, and logind suspends on a short press instead
through `/etc/systemd/logind.conf.d/50-power-key.conf`, installed and
reloaded (not restarted) by `scripts/setup-power-key.sh`, which bootstrap
runs. See [ADR-0021](adr/ADR-0021-let-logind-handle-the-power-key.md).

Check that logind picked it up; it should print `s "suspend"`:

```fish
busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandlePowerKey
```

If it still prints `poweroff`, reboot. Once niri fixes #2233, remove
`disable-power-key-handling` and the drop-in, then run
`./scripts/setup-greetd.sh`.

## Known issues

- [niri#3598](https://github.com/niri-wm/niri/issues/3598): on the Z13 the
  keyboard cover may not work when it is attached after niri started, because
  libinput treats it as an internal keyboard. The thread describes a udev
  hwdb override as the fix; it is a system file and is not managed here.
- The physical detach, the rotation mapping, touch after rotation, and
  squeekboard's automatic showing per application still need to be checked
  on the device.
