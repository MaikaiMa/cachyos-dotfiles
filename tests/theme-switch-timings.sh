#!/bin/sh
# Exercise theme-switch-timings on journal lines from stdin; never reads the real journal.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/theme-switch-timings.sh"

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

output=$(
	"$script" - <<'LOG'
2026-10-05T21:17:10.000000+0200 host quickshell[10]: qml: Appearance: theme call: dms ipc call theme light
2026-10-05T21:17:11.100000+0200 host dms[20]:   INFO qml: [Theme:1594] Setting desired theme - image mode: light (dynamic)
2026-10-05T21:17:11.900000+0200 host dms[20]:   INFO qml: [Theme:2126] Theme worker: Theme generation completed
2026-10-05T21:18:00.000000+0200 host quickshell[10]: qml: Appearance: theme call: dms ipc call theme dark
2026-10-05T21:18:00.010000+0200 host quickshell[10]: qml: Appearance: theme call: niri msg action do-screen-transition --delay-ms 1400
2026-10-05T21:18:00.030000+0200 host quickshell[10]: qml: Appearance: theme call: dms ipc call toast info
2026-10-05T21:18:00.450000+0200 host quickshell[10]: qml: Appearance: theme call: gsettings set org.gnome.desktop.interface gtk-theme adw-gtk3-dark
2026-10-05T21:18:00.460000+0200 host quickshell[10]: qml: Appearance: theme call: gsettings set org.gnome.desktop.interface color-scheme prefer-dark
2026-10-05T21:18:05.000000+0200 host dms[20]:   INFO qml: [Theme:1594] Setting desired theme - image mode: dark (dynamic)
2026-10-05T21:18:06.000000+0200 host dms[20]:   INFO qml: [Theme:2126] Theme worker: Theme generation completed
2026-10-05T23:59:59.000000+0200 host quickshell[10]: qml: Appearance: theme call: gsettings set org.gnome.desktop.interface color-scheme default
2026-10-06T00:00:01.000000+0200 host dms[20]:   INFO qml: [Theme:1594] Setting desired theme - image mode: light (dynamic)
2026-10-06T00:00:02.000000+0200 host dms[20]:   INFO qml: [Theme:2126] Theme worker: Theme generation completed
2026-10-06T08:00:00.000000+0200 host quickshell[10]: qml: Appearance: theme call: gsettings set org.gnome.desktop.interface color-scheme prefer-dark
LOG
)

printf '%s\n' "$output" | grep -q '^2026-10-05T21:17:10  pickup  1.10 s  render 0.80 s  total  1.90 s$' ||
	fail "A plain switch was not timed: $output"
printf '%s\n' "$output" | grep -q '^2026-10-05T23:59:59  pickup  2.00 s  render 1.00 s  total  3.00 s$' ||
	fail "A switch across midnight was not timed: $output"
printf '%s\n' "$output" | grep -q '^3 switches: fastest 1.90 s, median 3.00 s, slowest 6.00 s$' ||
	fail "The summary is wrong (an unfinished switch must not count): $output"
printf '%s\n' "$output" | grep -q '^crossfade delay covering the median: 2700 ms (lead 300 ms)$' ||
	fail "The suggested delay is wrong: $output"

if "$script" - </dev/null 2>/dev/null; then
	fail 'Empty input must fail.'
fi

printf '%s\n' 'theme-switch-timings: ok'
