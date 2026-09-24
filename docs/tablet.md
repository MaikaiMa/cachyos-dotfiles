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
| [`dotfilesKeyboard`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesKeyboard/README.md) | DMS bar, right of the dashboard button | Keyboard button, visible only while detached. |
| Rotation lock tile | [`dotfilesDashboard`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesDashboard/README.md) | Second tile of the toggle row. |
| Long press | [`dotfilesLauncher`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesLauncher/README.md), [`dotfilesWorkspaces`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesWorkspaces/README.md) | Toggles the niri overview. |

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

Deploy the dotfiles and the bar layout, which adds the keyboard widget and
restarts DMS:

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

The lock is the rotation-lock tile in the dashboard (`Mod+S`), or from a
terminal:

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
keyboard is on screen.

squeekboard also shows itself when a text field gains focus, but only when
GNOME's screen-keyboard setting is on. That setting is not managed: turning it
on also pops the keyboard up while the cover is attached. To try it:

```fish
gsettings set org.gnome.desktop.a11y.applications screen-keyboard-enabled true
```

Which applications trigger that depends on their support for the
`text-input-v3` protocol; GTK and Qt applications do, many others do not.

## Overview by long press

A long press on the launcher pill or on the workspace strip toggles the niri
overview; right click keeps doing the same, and a normal tap keeps its own
action. See the plugin READMEs for the details.

## Known issues

- [niri#3598](https://github.com/niri-wm/niri/issues/3598): on the Z13 the
  keyboard cover may not work when it is attached after niri started, because
  libinput treats it as an internal keyboard. The thread describes a udev
  hwdb override as the fix; it is a system file and is not managed here.
- The physical detach, the rotation mapping, touch after rotation, and
  squeekboard's automatic showing per application still need to be checked
  on the device.
