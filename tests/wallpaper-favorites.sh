#!/bin/sh
# Exercise wallpaper-favorites against a throwaway home.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
helper=$repo_root/chezmoi/dot_local/bin/executable_wallpaper-favorites
test_dir=$(mktemp -d)
trap 'rm -rf "$test_dir"' EXIT HUP INT TERM

fake_home=$test_dir/home
libraries=$fake_home/Pictures/Libraries
wallpapers=$fake_home/Pictures/Wallpapers
starred=$test_dir/starred
mkdir -p "$libraries/dharmx-walls/nord" "$libraries/dusklinux-walls/misc" \
	"$wallpapers" "$fake_home/Downloads"

: >"$libraries/dharmx-walls/nord/plain.jpg"
: >"$libraries/dharmx-walls/nord/a b.png"
: >"$libraries/dusklinux-walls/misc/été.webp"
: >"$libraries/dusklinux-walls/misc/UPPER.JPG"
: >"$libraries/dharmx-walls/README.md"
: >"$fake_home/Downloads/outside.jpg"

ln -s "$libraries/dharmx-walls/nord/plain.jpg" "$wallpapers/stale-link.jpg"
printf '%s\n' 'keep me' >"$wallpapers/notes.txt"

write_all_starred() {
	{
		printf 'file://%s/dharmx-walls/nord/plain.jpg\n' "$libraries"
		printf 'file://%s/dharmx-walls/nord/a%%20b.png\n' "$libraries"
		printf 'file://%s/dusklinux-walls/misc/%%C3%%A9t%%C3%%A9.webp\n' "$libraries"
		printf 'file://%s/dusklinux-walls/misc/UPPER.JPG\n' "$libraries"
		printf 'file://%s/dharmx-walls/README.md\n' "$libraries"
		printf 'file://%s/Downloads/outside.jpg\n' "$fake_home"
		printf 'file://%s/dharmx-walls/nord/gone.jpg\n' "$libraries"
	} >"$starred"
}

run_helper() {
	HOME=$fake_home \
		WALLPAPER_FAVORITES_STARRED_FILE=$starred \
		"$helper" "$@"
}

fail() {
	printf '%s\n' "$1" >&2
	exit 1
}

assert_summary() {
	if [ "$1" != "$2" ]; then
		printf 'Expected summary: %s\n' "$2" >&2
		printf 'Actual summary:   %s\n' "$1" >&2
		exit 1
	fi
}

assert_link() {
	[ -h "$1" ] || fail "Expected a symlink: $1"
	actual_target=$(readlink "$1")
	[ "$actual_target" = "$2" ] ||
		fail "Symlink $1 points at $actual_target, expected $2"
}

assert_links_are() {
	find "$wallpapers" -mindepth 1 -maxdepth 1 -type l |
		sed "s|^$wallpapers/||" | sort >"$test_dir/actual-links"
	sort >"$test_dir/expected-links"
	diff -u "$test_dir/expected-links" "$test_dir/actual-links" ||
		fail 'Symlink set in the favourites folder is wrong.'
}

write_all_starred

summary=$(run_helper sync 2>"$test_dir/first-stderr")
assert_summary "$summary" 'wallpaper-favorites: 4 linked, 4 added, 1 removed, 3 skipped'
grep -q 'ignoring non-symlink' "$test_dir/first-stderr" ||
	fail 'The regular file in the favourites folder was not reported.'

assert_links_are <<EOF
dharmx-walls-nord-a b.png
dharmx-walls-nord-plain.jpg
dusklinux-walls-misc-UPPER.JPG
dusklinux-walls-misc-été.webp
EOF

assert_link "$wallpapers/dharmx-walls-nord-plain.jpg" \
	"$libraries/dharmx-walls/nord/plain.jpg"
assert_link "$wallpapers/dharmx-walls-nord-a b.png" \
	"$libraries/dharmx-walls/nord/a b.png"
assert_link "$wallpapers/dusklinux-walls-misc-été.webp" \
	"$libraries/dusklinux-walls/misc/été.webp"
assert_link "$wallpapers/dusklinux-walls-misc-UPPER.JPG" \
	"$libraries/dusklinux-walls/misc/UPPER.JPG"

[ ! -e "$wallpapers/stale-link.jpg" ] || fail 'The stale symlink was not removed.'
[ -f "$wallpapers/notes.txt" ] || fail 'The regular file was removed.'
[ "$(cat "$wallpapers/notes.txt")" = 'keep me' ] ||
	fail 'The regular file was modified.'

summary=$(run_helper sync 2>/dev/null)
assert_summary "$summary" 'wallpaper-favorites: 4 linked, 0 added, 0 removed, 3 skipped'

run_helper list >"$test_dir/listed"
sort >"$test_dir/expected-listed" <<EOF
$libraries/dharmx-walls/nord/a b.png
$libraries/dharmx-walls/nord/plain.jpg
$libraries/dusklinux-walls/misc/UPPER.JPG
$libraries/dusklinux-walls/misc/été.webp
EOF
diff -u "$test_dir/expected-listed" "$test_dir/listed" ||
	fail 'list printed the wrong favourite targets.'

grep -v 'a%20b.png' "$starred" >"$test_dir/unstarred"
mv "$test_dir/unstarred" "$starred"
summary=$(run_helper sync 2>/dev/null)
assert_summary "$summary" 'wallpaper-favorites: 3 linked, 0 added, 1 removed, 3 skipped'
[ ! -e "$wallpapers/dharmx-walls-nord-a b.png" ] ||
	fail 'Unstarring did not remove the symlink.'

rm "$wallpapers/dharmx-walls-nord-plain.jpg"
printf '%s\n' 'not a symlink' >"$wallpapers/dharmx-walls-nord-plain.jpg"
summary=$(run_helper sync 2>"$test_dir/blocked-stderr")
assert_summary "$summary" 'wallpaper-favorites: 2 linked, 0 added, 0 removed, 3 skipped'
grep -q 'cannot link' "$test_dir/blocked-stderr" ||
	fail 'The blocking regular file was not reported.'
[ "$(cat "$wallpapers/dharmx-walls-nord-plain.jpg")" = 'not a symlink' ] ||
	fail 'A regular file at a wanted link path was overwritten.'

run_helper --help | grep -q '^Usage:' || fail 'Help output is missing a usage line.'

printf '%s\n' 'wallpaper-favorites tests passed.'
