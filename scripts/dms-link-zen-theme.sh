#!/bin/sh
# Zen re-reads userChrome.css only at startup, so a re-render never shows
# without a restart even when this script changes nothing.
set -eu

zen_root="$HOME/.config/zen"
profiles_ini="$zen_root/profiles.ini"
theme_css="$zen_root/dms-userChrome.css"
colors_css="$zen_root/dms-colors.css"
prefs='toolkit.legacyUserProfileCustomizations.stylesheets zen.widget.linux.transparency browser.tabs.allow_transparent_browser zen.theme.use-system-colors'
dry_run=0

usage() {
	printf 'Usage: %s [--dry-run]\n' "${0##*/}" >&2
}

for arg in "$@"; do
	case "$arg" in
	--dry-run)
		dry_run=1
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		usage
		exit 1
		;;
	esac
done

[ -f "$theme_css" ] || {
	printf 'dms-link-zen-theme: %s not found; apply the dotfiles first (./scripts/bootstrap.sh)\n' "$theme_css" >&2
	exit 1
}

[ -f "$colors_css" ] || {
	printf 'dms-link-zen-theme: %s not found; switch the DMS theme mode in the Control Center to render it, see "Triggering a re-render" in docs/dms.md\n' "$colors_css" >&2
	exit 1
}

[ -f "$profiles_ini" ] || {
	printf 'dms-link-zen-theme: %s not found; start Zen once to create a profile\n' "$profiles_ini" >&2
	exit 1
}

# ini_section NAME FILE prints the body of the first "[NAME]" section.
ini_section() {
	awk -v name="$1" '
		/^\[/ { in_section = ($0 == "[" name "]") }
		in_section && !/^\[/ { print }
	' "$2"
}

# ini_value KEY SECTION_BODY prints the value of the first "KEY=" line.
ini_value() {
	printf '%s\n' "$2" | sed -n "s/^$1=//p" | head -n 1
}

install_section=$(awk '/^\[Install/ { print substr($0, 2, length($0) - 2); exit }' "$profiles_ini")
profile_path=
if [ -n "$install_section" ]; then
	body=$(ini_section "$install_section" "$profiles_ini")
	profile_path=$(ini_value 'Default' "$body")
	if [ -n "$profile_path" ]; then
		profile_dir="$zen_root/$profile_path"
	fi
fi

if [ -z "$profile_path" ]; then
	default_sections=$(awk '/^\[Profile/ { print substr($0, 2, length($0) - 2) }' "$profiles_ini")
	section_count=$(printf '%s\n' "$default_sections" | grep -c '.')

	default_section=
	for section in $default_sections; do
		body=$(ini_section "$section" "$profiles_ini")
		if [ "$(ini_value 'Default' "$body")" = '1' ]; then
			default_section=$section
			default_body=$body
			break
		fi
	done

	if [ -z "$default_section" ] && [ "$section_count" -eq 1 ]; then
		default_section=$default_sections
		default_body=$(ini_section "$default_section" "$profiles_ini")
	fi

	[ -n "$default_section" ] || {
		printf 'dms-link-zen-theme: could not determine the default Zen profile from %s\n' "$profiles_ini" >&2
		exit 1
	}

	profile_path=$(ini_value 'Path' "$default_body")
	is_relative=$(ini_value 'IsRelative' "$default_body")
	if [ "$is_relative" = '0' ]; then
		profile_dir=$profile_path
	else
		profile_dir="$zen_root/$profile_path"
	fi
fi

[ -d "$profile_dir" ] || {
	printf 'dms-link-zen-theme: profile directory %s does not exist\n' "$profile_dir" >&2
	exit 1
}

chrome_dir="$profile_dir/chrome"
user_js="$profile_dir/user.js"

# link_action LINK TARGET prints create, replace or none, and refuses to
# replace a regular file.
link_action() {
	if [ -L "$1" ]; then
		if [ "$(readlink "$1")" = "$2" ]; then
			printf 'none\n'
		else
			printf 'replace\n'
		fi
	elif [ -e "$1" ]; then
		printf 'dms-link-zen-theme: %s already exists and is not a symlink; move it aside (it may be your own CSS) and re-run\n' "$1" >&2
		return 1
	else
		printf 'create\n'
	fi
}

user_chrome_action=$(link_action "$chrome_dir/userChrome.css" "$theme_css")
colors_action=$(link_action "$chrome_dir/dms-colors.css" "$colors_css")

missing_prefs=
for pref in $prefs; do
	if [ -f "$user_js" ] && grep -Fq "user_pref(\"$pref\", true);" "$user_js"; then
		continue
	fi
	if [ -f "$user_js" ] && grep -Fq "\"$pref\"" "$user_js"; then
		printf 'dms-link-zen-theme: %s already sets %s to something other than true\n' "$user_js" "$pref" >&2
		exit 1
	fi
	missing_prefs="$missing_prefs $pref"
done

changed=0

# apply_link ACTION LINK TARGET
apply_link() {
	case "$1" in
	none)
		printf 'dms-link-zen-theme: already linked, %s -> %s\n' "$2" "$3"
		;;
	replace)
		previous_target=$(readlink "$2")
		if [ "$dry_run" -eq 1 ]; then
			printf 'dms-link-zen-theme: dry run, would replace the symlink %s (currently -> %s) with -> %s\n' "$2" "$previous_target" "$3"
		else
			ln -sfn "$3" "$2"
			printf 'dms-link-zen-theme: replaced the symlink %s (was -> %s) with -> %s\n' "$2" "$previous_target" "$3"
			changed=1
		fi
		;;
	create)
		if [ "$dry_run" -eq 1 ]; then
			printf 'dms-link-zen-theme: dry run, would link %s -> %s\n' "$2" "$3"
		else
			mkdir -p "$chrome_dir"
			ln -s "$3" "$2"
			printf 'dms-link-zen-theme: linked %s -> %s\n' "$2" "$3"
			changed=1
		fi
		;;
	esac
}

apply_link "$user_chrome_action" "$chrome_dir/userChrome.css" "$theme_css"
apply_link "$colors_action" "$chrome_dir/dms-colors.css" "$colors_css"

if [ -z "$missing_prefs" ]; then
	printf 'dms-link-zen-theme: %s already sets every required pref\n' "$user_js"
elif [ "$dry_run" -eq 1 ]; then
	printf 'dms-link-zen-theme: dry run, would add to %s:%s\n' "$user_js" "$missing_prefs"
else
	if [ -s "$user_js" ] && [ -n "$(tail -c 1 "$user_js")" ]; then
		printf '\n' >>"$user_js"
	fi
	for pref in $missing_prefs; do
		printf 'user_pref("%s", true);\n' "$pref" >>"$user_js"
	done
	printf 'dms-link-zen-theme: added to %s:%s\n' "$user_js" "$missing_prefs"
	changed=1
fi

if [ "$changed" -eq 1 ]; then
	printf 'dms-link-zen-theme: restart Zen to load the theme; colours only update in Zen after a restart\n'
fi
