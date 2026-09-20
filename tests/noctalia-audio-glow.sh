#!/bin/sh
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/chezmoi/dot_local/bin/executable_sync-noctalia-audio-glow"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fake_bin=$test_root/bin
config_home=$test_root/config
calls=$test_root/calls
mkdir -p "$fake_bin" "$config_home/noctalia"

cat >"$fake_bin/noctalia-test" <<'EOF'
#!/bin/sh
case "$1 $2 $3" in
"config export merged")
	cat "$AUDIO_GLOW_MERGED_CONFIG"
	;;
"config validate "*)
	exit 0
	;;
"msg config-reload ")
	printf '%s\n' reload >>"$AUDIO_GLOW_CALLS"
	;;
*)
	printf 'Unexpected noctalia arguments: %s\n' "$*" >&2
	exit 1
	;;
esac
EOF

cat >"$fake_bin/niri-test" <<'EOF'
#!/bin/sh
if [ "$*" != "msg -j outputs" ]; then
	printf 'Unexpected niri arguments: %s\n' "$*" >&2
	exit 1
fi
cat "$AUDIO_GLOW_OUTPUTS"
EOF
chmod +x "$fake_bin/noctalia-test" "$fake_bin/niri-test"

merged=$test_root/merged.toml
outputs=$test_root/outputs.json
cat >"$merged" <<'EOF'
[bar]
order = [ "dotfiles", "default" ]

    [bar.dotfiles]
    enabled = true
    position = "top"
    thickness = 34
    padding = 4
    margin_ends = 12
    margin_edge = 4
    radius = 16
EOF
cat >"$outputs" <<'EOF'
{"eDP-1":{"logical":{"x":0,"y":0,"width":1462,"height":914,"scale":1.75,"transform":"Normal"}}}
EOF

run_sync() {
	PATH="$fake_bin:$PATH" \
		NOCTALIA_COMMAND=noctalia-test \
		NIRI_COMMAND=niri-test \
		NOCTALIA_CONFIG_HOME="$config_home" \
		AUDIO_GLOW_MERGED_CONFIG="$merged" \
		AUDIO_GLOW_OUTPUTS="$outputs" \
		AUDIO_GLOW_CALLS="$calls" \
		"$script"
}

run_sync
target=$config_home/noctalia/desktop-audio-glow.generated.toml
for expected in \
	'[desktop_widgets.widget."audio-glow@eDP-1"]' \
	'cx = 731' \
	'cy = 21' \
	'box_width = 1426' \
	'box_height = 26' \
	'color_1 = "primary"' \
	'color_2 = "secondary"' \
	'show_when_idle = false'; do
	if ! grep -Fq "$expected" "$target"; then
		printf 'Generated audio glow is missing: %s\n' "$expected" >&2
		exit 1
	fi
done
noctalia config validate "$config_home/noctalia" >/dev/null
if [ "$(wc -l <"$calls")" -ne 1 ]; then
	printf '%s\n' 'Initial audio-glow generation did not reload Noctalia exactly once.' >&2
	exit 1
fi

run_sync
if [ "$(wc -l <"$calls")" -ne 1 ]; then
	printf '%s\n' 'Unchanged audio-glow configuration reloaded Noctalia.' >&2
	exit 1
fi

sed 's/padding = 4/padding = 6/' "$merged" >"$test_root/padded.toml"
merged=$test_root/padded.toml
run_sync
for expected in \
	'box_width = 1430' \
	'box_height = 22'; do
	if ! grep -Fq "$expected" "$target"; then
		printf 'Adjusted bar padding did not update the audio glow: %s\n' "$expected" >&2
		exit 1
	fi
done
if [ "$(wc -l <"$calls")" -ne 2 ]; then
	printf '%s\n' 'Changed bar geometry did not reload Noctalia exactly once.' >&2
	exit 1
fi

sed 's/enabled = true/enabled = false/' "$merged" >"$test_root/disabled.toml"
merged=$test_root/disabled.toml
run_sync
if grep -Fq '[desktop_widgets]' "$target"; then
	printf '%s\n' 'Disabled dotfiles bar left the audio glow enabled.' >&2
	exit 1
fi

printf '%s\n' 'Noctalia audio-glow tests passed.'
