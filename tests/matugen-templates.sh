#!/bin/sh
# Render every user matugen template into an isolated home, in both modes;
# post hooks are stripped so nothing live (lightbar, terminals, Vicinae) is touched.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
config="$repo_root/chezmoi/dot_config/matugen/config.toml"
templates="$repo_root/chezmoi/dot_config/matugen/templates"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

command -v matugen >/dev/null 2>&1 || fail 'matugen-templates: matugen is required but not installed'

sed -n 's|^input_path = "~/.config/matugen/templates/\(.*\)"$|\1|p' "$config" | while read -r name; do
	[ -f "$templates/$name" ] || fail "matugen-templates: $config names a template that does not exist: $name"
done
listed=$(grep -c '^input_path = ' "$config")
present=$(find "$templates" -type f | wc -l)
[ "$listed" -eq "$present" ] || fail "matugen-templates: $listed templates are registered but $present files are in templates/"

# render MODE HOME writes every template for MODE under HOME.
render() {
	mkdir -p "$2"
	sed -e '/^post_hook = /d' \
		-e "s|~/.config/matugen/templates/|$templates/|" \
		-e "s|~/|$2/|" "$config" >"$2/config.toml"
	matugen color hex '#4c8c4a' -c "$2/config.toml" -m "$1" -q
}

render dark "$test_root/dark"
render light "$test_root/light"

sed -n 's|^output_path = "~/\(.*\)"$|\1|p' "$config" | while read -r output; do
	for mode in dark light; do
		file="$test_root/$mode/$output"
		[ -s "$file" ] || fail "matugen-templates: $output was not rendered for $mode"
		! grep -q '{{' "$file" || fail "matugen-templates: $output still contains a template tag in $mode"
	done
	if cmp -s "$test_root/dark/$output" "$test_root/light/$output"; then
		fail "matugen-templates: $output renders the same for dark and light"
	fi
done

hylki='.var/app/co.hyprlab.Hylki/config/gtk-4.0/gtk.css'
for color in window_bg_color view_bg_color accent_bg_color; do
	grep -q "^@define-color $color #[0-9a-fA-F]\{6\};$" "$test_root/dark/$hylki" ||
		fail "matugen-templates: the Hylki stylesheet does not define $color"
done

printf '%s\n' 'matugen-templates: ok'
