#!/bin/sh
# Samples what the bar costs over a window of seconds: CPU and GPU time per
# process (bar, niri, dms), whole-GPU busy, battery draw while discharging,
# package power from RAPL when it is readable, the child CPU time the bar
# spawned, and the frames each surface presented. Reads only; needs nothing
# installed beyond coreutils and quickshell.
#
#   scripts/bar-power-sample.sh [seconds] [label]
set -eu

seconds=${1:-30}
label=${2:-}
tick=$(getconf CLK_TCK)
card=/sys/class/drm/card1/device
rapl=/sys/class/powercap/intel-rapl:0/energy_uj

# RAPL is root-only; a cached sudo ticket (`sudo -v` first) lets the script
# stay the desktop user, which the Frames IPC needs.
read_rapl() {
	if [ -r "$rapl" ]; then
		cat "$rapl"
	elif sudo -n true 2>/dev/null; then
		sudo -n cat "$rapl"
	fi
}
bat=/sys/class/power_supply/BAT0

pid_of() {
	pgrep -x -f "$1" 2>/dev/null | head -n 1
}

bar_pid=$(pid_of '/usr/bin/quickshell -c bar -n' || true)
niri_pid=$(pgrep -x niri 2>/dev/null | head -n 1 || true)
dms_pid=$(pid_of '/usr/bin/dms run --session' || true)
[ -n "$bar_pid" ] || {
	echo "bar is not running (quickshell -c bar -n)" >&2
	exit 1
}

# Sum of gfx engine time over the process's distinct drm clients, in ns.
gfx_ns() {
	seen=
	total=0
	for f in /proc/"$1"/fdinfo/*; do
		[ -r "$f" ] || continue
		id=$(grep -s '^drm-client-id:' "$f" | awk '{print $2}')
		[ -n "$id" ] || continue
		case " $seen " in *" $id "*) continue ;; esac
		seen="$seen $id"
		ns=$(grep -s '^drm-engine-gfx:' "$f" | awk '{print $2}')
		total=$((total + ${ns:-0}))
	done
	echo "$total"
}

# utime+stime (field 14+15) and cutime+cstime (16+17) in clock ticks.
cpu_ticks() { awk '{print $14 + $15}' /proc/"$1"/stat; }
child_ticks() { awk '{print $16 + $17}' /proc/"$1"/stat; }
sys_ticks() { awk '/^cpu /{print $2+$3+$4+$5+$6+$7+$8}' /proc/stat; }
sys_busy_ticks() { awk '/^cpu /{print $2+$3+$4+$6+$7+$8}' /proc/stat; }

sample() {
	# $1 = pid, prints "cpu gfx"
	if [ -n "$1" ]; then
		printf '%s %s\n' "$(cpu_ticks "$1")" "$(gfx_ns "$1")"
	else
		echo "0 0"
	fi
}

read -r bar_cpu0 bar_gfx0 <<EOF
$(sample "$bar_pid")
EOF
read -r niri_cpu0 niri_gfx0 <<EOF
$(sample "$niri_pid")
EOF
read -r dms_cpu0 dms_gfx0 <<EOF
$(sample "$dms_pid")
EOF
child0=$(child_ticks "$bar_pid")
sys0=$(sys_ticks)
busy0=$(sys_busy_ticks)
rapl0=$(read_rapl)

busy_sum=0
power_sum=0
power_n=0
i=0
while [ "$i" -lt "$seconds" ]; do
	sleep 1
	busy_sum=$((busy_sum + $(cat "$card/gpu_busy_percent")))
	if [ "$(cat "$bat/status")" = "Discharging" ]; then
		power_sum=$((power_sum + $(cat "$bat/power_now")))
		power_n=$((power_n + 1))
	fi
	i=$((i + 1))
done

read -r bar_cpu1 bar_gfx1 <<EOF
$(sample "$bar_pid")
EOF
read -r niri_cpu1 niri_gfx1 <<EOF
$(sample "$niri_pid")
EOF
read -r dms_cpu1 dms_gfx1 <<EOF
$(sample "$dms_pid")
EOF
child1=$(child_ticks "$bar_pid")
sys1=$(sys_ticks)
busy1=$(sys_busy_ticks)
rapl1=$(read_rapl)

pct_cpu() { awk -v d="$(($2 - $1))" -v t="$tick" -v s="$seconds" 'BEGIN{printf "%.1f", d * 100 / t / s}'; }
pct_gfx() { awk -v d="$(($2 - $1))" -v s="$seconds" 'BEGIN{printf "%.1f", d / 1e7 / s}'; }

echo "== ${label:-sample} ${seconds}s $(date +%H:%M:%S) ac=$(cat /sys/class/power_supply/AC0/online)"
printf '%-6s cpu %5s %%  gpu %5s %%\n' bar "$(pct_cpu "$bar_cpu0" "$bar_cpu1")" "$(pct_gfx "$bar_gfx0" "$bar_gfx1")"
[ -n "$niri_pid" ] && printf '%-6s cpu %5s %%  gpu %5s %%\n' niri "$(pct_cpu "$niri_cpu0" "$niri_cpu1")" "$(pct_gfx "$niri_gfx0" "$niri_gfx1")"
[ -n "$dms_pid" ] && printf '%-6s cpu %5s %%  gpu %5s %%\n' dms "$(pct_cpu "$dms_cpu0" "$dms_cpu1")" "$(pct_gfx "$dms_gfx0" "$dms_gfx1")"
printf '%-6s cpu %5s %% of all cores  gpu busy %s %% (sysfs avg)\n' system \
	"$(awk -v b="$((busy1 - busy0))" -v t="$((sys1 - sys0))" 'BEGIN{printf "%.1f", b * 100 / t}')" \
	"$((busy_sum / seconds))"
printf 'bar children cpu %s s (spawned helpers)\n' "$(awk -v d="$((child1 - child0))" -v t="$tick" 'BEGIN{printf "%.2f", d / t}')"
if [ "$power_n" -gt 0 ]; then
	printf 'battery %s W (discharging, %s samples)\n' "$(awk -v p="$power_sum" -v n="$power_n" 'BEGIN{printf "%.2f", p / n / 1e6}')" "$power_n"
else
	echo "battery: not discharging, no draw figure"
fi
if [ -n "$rapl0" ] && [ -n "$rapl1" ]; then
	printf 'package %s W (RAPL)\n' "$(awk -v d="$((rapl1 - rapl0))" -v s="$seconds" 'BEGIN{printf "%.2f", d / 1e6 / s}')"
else
	echo "package: RAPL not readable (run sudo -v first)"
fi
window=$((seconds > 59 ? 59 : seconds))
frames=$(quickshell ipc -c bar call bardebug frames "$window" 2>/dev/null || true)
echo "frames ${frames:-unavailable}"
