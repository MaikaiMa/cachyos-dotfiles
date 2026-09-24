#!/bin/sh
# Exercise dms-link-zen-theme against isolated fake homes; never touches the real home.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
script="$repo_root/scripts/dms-link-zen-theme.sh"
test_root=$(mktemp -d)
trap 'rm -rf "$test_root"' EXIT HUP INT TERM

prefs='toolkit.legacyUserProfileCustomizations.stylesheets zen.widget.linux.transparency browser.tabs.allow_transparent_browser zen.theme.use-system-colors'

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

# write_theme HOME deploys the chezmoi CSS and a rendered colour file.
write_theme() {
	mkdir -p "$1/.config/zen"
	cp "$repo_root/chezmoi/dot_config/private_zen/dms-userChrome.css" "$1/.config/zen/dms-userChrome.css"
	printf ':root { --dms-primary: #81d5ce; }\n' >"$1/.config/zen/dms-colors.css"
}

# write_single_profile HOME writes a profiles.ini with one only.default profile.
write_single_profile() {
	mkdir -p "$1/.config/zen/only.default"
	cat >"$1/.config/zen/profiles.ini" <<'INI'
[Profile0]
Name=only
IsRelative=1
Path=only.default
Default=1
INI
}

run_link() {
	home=$1
	shift
	HOME="$home" XDG_CONFIG_HOME="$home/.config" "$script" "$@"
}

# assert_links CHROME_DIR HOME
assert_links() {
	[ "$(readlink "$1/userChrome.css")" = "$2/.config/zen/dms-userChrome.css" ] ||
		fail "userChrome.css in $1 does not point at dms-userChrome.css."
	[ "$(readlink "$1/dms-colors.css")" = "$2/.config/zen/dms-colors.css" ] ||
		fail "dms-colors.css in $1 does not point at the rendered colours."
}

# assert_prefs_once USER_JS
assert_prefs_once() {
	for pref in $prefs; do
		count=$(grep -c "user_pref(\"$pref\", true);" "$1" || true)
		[ "$count" -eq 1 ] || fail "$1 sets $pref $count times instead of once."
	done
}

# Case: the Install section wins over a Profile with Default=1, and paths with
# spaces round-trip correctly.
home1="$test_root/case1"
write_theme "$home1"
mkdir -p "$home1/.config/zen/rklovb65.Default (release)"
mkdir -p "$home1/.config/zen/sfvfa26a.Default Profile"
cat >"$home1/.config/zen/profiles.ini" <<'EOF_INI'
[General]
StartWithLastProfile=1
Version=2

[Profile0]
Name=Default (release)
IsRelative=1
Path=rklovb65.Default (release)

[Install15B76BAA26BA15E7]
Default=rklovb65.Default (release)
Locked=1

[Profile1]
Name=Default Profile
IsRelative=1
Path=sfvfa26a.Default Profile
Default=1
EOF_INI

case1_profile="$home1/.config/zen/rklovb65.Default (release)"
case1_chrome="$case1_profile/chrome"
user_js="$case1_profile/user.js"

dry_run_out=$(run_link "$home1" --dry-run)
case $dry_run_out in
*"would link $case1_chrome/userChrome.css"*) ;;
*) fail "dry-run did not target the Install-section profile: $dry_run_out" ;;
esac
case $dry_run_out in
*"would link $case1_chrome/dms-colors.css"*) ;;
*) fail "dry-run did not plan the colour link: $dry_run_out" ;;
esac
case $dry_run_out in
*'zen.widget.linux.transparency'*) ;;
*) fail "dry-run did not plan the transparency pref: $dry_run_out" ;;
esac
[ ! -e "$case1_chrome" ] || fail 'dry-run created the chrome directory.'
[ ! -e "$user_js" ] || fail 'dry-run created user.js.'

first_out=$(run_link "$home1")
case $first_out in
*'restart Zen'*) ;;
*) fail "a changing run did not print the restart notice: $first_out" ;;
esac
assert_links "$case1_chrome" "$home1"
[ ! -e "$home1/.config/zen/sfvfa26a.Default Profile/chrome" ] ||
	fail 'the non-Install Default=1 profile was linked instead.'
assert_prefs_once "$user_js"

# Second run: no-op.
second_out=$(run_link "$home1")
case $second_out in
*'already linked'*) ;;
*) fail "second run did not report the existing links: $second_out" ;;
esac
case $second_out in
*'restart Zen'*) fail 'a no-op second run printed the restart notice.' ;;
esac
assert_links "$case1_chrome" "$home1"
assert_prefs_once "$user_js"

# --dry-run on an already-linked profile changes nothing.
before_dry2=$(cat "$user_js")
dry_run_out2=$(run_link "$home1" --dry-run)
case $dry_run_out2 in
*'would'*) fail "dry-run on a linked profile planned a change: $dry_run_out2" ;;
esac
[ "$(cat "$user_js")" = "$before_dry2" ] || fail 'dry-run on a linked profile changed user.js.'

# Case: a pre-existing regular userChrome.css must not be touched, and nothing
# else is changed either.
home2="$test_root/case2"
write_theme "$home2"
write_single_profile "$home2"
mkdir -p "$home2/.config/zen/only.default/chrome"
printf '/* my own css */\n' >"$home2/.config/zen/only.default/chrome/userChrome.css"
cp "$home2/.config/zen/only.default/chrome/userChrome.css" "$test_root/case2-before.css"

if run_link "$home2" >/dev/null 2>"$test_root/case2.err"; then
	fail 'linking over a regular userChrome.css must fail.'
fi
grep -qi 'move it aside' "$test_root/case2.err" || fail 'the regular-file failure did not mention moving it aside.'
cmp -s "$home2/.config/zen/only.default/chrome/userChrome.css" "$test_root/case2-before.css" ||
	fail 'the existing regular userChrome.css was modified.'
[ ! -e "$home2/.config/zen/only.default/chrome/dms-colors.css" ] || fail 'a refused run still linked dms-colors.css.'
[ ! -e "$home2/.config/zen/only.default/user.js" ] || fail 'a refused run still wrote user.js.'

# Case: a missing dms-userChrome.css must fail clearly.
home3="$test_root/case3"
write_single_profile "$home3"
printf ':root {}\n' >"$home3/.config/zen/dms-colors.css"
if run_link "$home3" >/dev/null 2>"$test_root/case3.err"; then
	fail 'a missing dms-userChrome.css must fail.'
fi
grep -q 'bootstrap' "$test_root/case3.err" || fail 'the missing dms-userChrome.css failure did not point at bootstrap.'

# Case: missing rendered colours must fail clearly.
home3b="$test_root/case3b"
write_theme "$home3b"
write_single_profile "$home3b"
rm "$home3b/.config/zen/dms-colors.css"
if run_link "$home3b" >/dev/null 2>"$test_root/case3b.err"; then
	fail 'a missing dms-colors.css must fail.'
fi
grep -q 'Triggering a re-render' "$test_root/case3b.err" || fail 'the missing dms-colors.css failure did not explain the re-render.'

# Case: missing profiles.ini must fail clearly.
home4="$test_root/case4"
write_theme "$home4"
if run_link "$home4" >/dev/null 2>"$test_root/case4.err"; then
	fail 'a missing profiles.ini must fail.'
fi
grep -qi 'start Zen once' "$test_root/case4.err" || fail 'the missing profiles.ini failure did not suggest starting Zen.'

# Case: a conflicting pref value must fail clearly before changing anything.
home5="$test_root/case5"
write_theme "$home5"
write_single_profile "$home5"
printf 'user_pref("zen.widget.linux.transparency", false);\n' >"$home5/.config/zen/only.default/user.js"
if run_link "$home5" >/dev/null 2>"$test_root/case5.err"; then
	fail 'a conflicting pref value must fail.'
fi
grep -q 'zen.widget.linux.transparency' "$test_root/case5.err" || fail 'the conflicting pref failure did not name the pref.'
[ ! -e "$home5/.config/zen/only.default/chrome" ] || fail 'a conflicting pref must not create the links.'

# Case: IsRelative=0 with an absolute path works.
home6="$test_root/case6"
abs_profile="$test_root/external-profile"
mkdir -p "$abs_profile"
write_theme "$home6"
cat >"$home6/.config/zen/profiles.ini" <<EOF_INI
[Profile0]
Name=external
IsRelative=0
Path=$abs_profile
Default=1
EOF_INI
run_link "$home6" >/dev/null
assert_links "$abs_profile/chrome" "$home6"

# Case: the former link to DMS's zen.css is replaced, and the script says so.
home7="$test_root/case7"
write_theme "$home7"
write_single_profile "$home7"
mkdir -p "$home7/.config/zen/only.default/chrome" "$home7/.config/DankMaterialShell"
printf ':root {}\n' >"$home7/.config/DankMaterialShell/zen.css"
ln -s "$home7/.config/DankMaterialShell/zen.css" "$home7/.config/zen/only.default/chrome/userChrome.css"
replace_out=$(run_link "$home7")
case $replace_out in
*"was -> $home7/.config/DankMaterialShell/zen.css"*) ;;
*) fail "replacing the zen.css symlink did not report it: $replace_out" ;;
esac
assert_links "$home7/.config/zen/only.default/chrome" "$home7"

# Case: prefs already present are kept, the rest are appended on their own
# line even when user.js lacks a trailing newline.
home8="$test_root/case8"
write_theme "$home8"
write_single_profile "$home8"
case8_js="$home8/.config/zen/only.default/user.js"
printf 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);\nuser_pref("other.pref", 1);' >"$case8_js"
run_link "$home8" >/dev/null
assert_prefs_once "$case8_js"
grep -qx 'user_pref("other.pref", 1);' "$case8_js" || fail 'the unrelated last line of user.js was damaged.'

printf '%s\n' 'dms-link-zen-theme tests passed.'
