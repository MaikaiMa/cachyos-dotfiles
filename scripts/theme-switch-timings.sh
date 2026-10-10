#!/bin/sh
# Pair each Light/Dark switch the bar made with DMS's render in the user
# journal and print how long the desktop took, to tune the crossfade delay
# (Theme.themeCrossfadeDelay in the bar; see "Crossfade delay, measured" in
# docs/shell.md). Switches made through the portal before 2026-10-10 (a bare
# colour-scheme write) are paired as well. Reads the journal of the last seven days, or the given
# `journalctl --since` value, or journal lines from stdin with `-`.
set -eu

lead_ms=300
since=-7d
usage() {
	printf 'Usage: %s [SINCE | -]\n' "${0##*/}" >&2
}

case "${1-}" in
-h | --help)
	usage
	exit 0
	;;
'') ;;
*)
	since=$1
	;;
esac

if [ "$since" = "-" ]; then
	input=$(cat)
else
	command -v journalctl >/dev/null 2>&1 || {
		printf 'theme-switch-timings: journalctl is required\n' >&2
		exit 1
	}
	input=$(journalctl --user --no-pager -o short-iso-precise --since "$since" 2>/dev/null |
		grep -E 'theme call: (gsettings set org.gnome.desktop.interface color-scheme|dms ipc call theme (light|dark))|Setting desired theme|Theme generation completed' || true)
fi

[ -n "$input" ] || {
	printf 'theme-switch-timings: no Light/Dark switch found since %s\n' "$since" >&2
	exit 1
}

# Seconds since midnight from the ISO timestamp in column 1; a switch that
# crosses midnight gets a day added.
printf '%s\n' "$input" | awk -v lead_ms="$lead_ms" '
function seconds(stamp,    t) {
	t = substr(stamp, 12, 15)
	return substr(t, 1, 2) * 3600 + substr(t, 4, 2) * 60 + substr(t, 7)
}
function since(start, now) {
	now -= start
	return now < 0 ? now + 86400 : now
}
/theme call: (gsettings set org.gnome.desktop.interface color-scheme|dms ipc call theme (light|dark))/ {
	# The bar also writes the colour scheme after the call; that is not a new switch.
	if (start != "" && $0 ~ /gsettings/)
		next
	start = seconds($1)
	stamp = substr($1, 1, 19)
	pickup = render = ""
	next
}
/Setting desired theme/ && start != "" {
	pickup = since(start, seconds($1))
	next
}
/Theme generation completed/ && start != "" && pickup != "" {
	render = since(start, seconds($1)) - pickup
	total = pickup + render
	n++
	totals[n] = total
	printf "%s  pickup %5.2f s  render %4.2f s  total %5.2f s\n", stamp, pickup, render, total
	start = ""
}
function sort(values, count,    i, j, v) {
	for (i = 2; i <= count; i++) {
		v = values[i]
		for (j = i - 1; j >= 1 && values[j] > v; j--)
			values[j + 1] = values[j]
		values[j + 1] = v
	}
}
END {
	if (n == 0) {
		print "no complete switch (bar call, DMS pick-up and render) found" > "/dev/stderr"
		exit 1
	}
	sort(totals, n)
	median = n % 2 ? totals[(n + 1) / 2] : (totals[n / 2] + totals[n / 2 + 1]) / 2
	printf "%d switches: fastest %.2f s, median %.2f s, slowest %.2f s\n", n, totals[1], median, totals[n]
	delay = int((median * 1000 - lead_ms + 99) / 100) * 100
	printf "crossfade delay covering the median: %d ms (lead %d ms)\n", delay, lead_ms
}'
