#!/bin/sh
# Lint the repository-owned Quickshell bar against the installed Quickshell modules.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)
bar_dir="$repo_root/chezmoi/dot_config/quickshell/bar"
qml_import_path=/usr/lib/qt6/qml

qmllint_command=qmllint
if ! command -v "$qmllint_command" >/dev/null 2>&1; then
	qmllint_command=/usr/lib/qt6/bin/qmllint
fi
command -v "$qmllint_command" >/dev/null 2>&1 || {
	printf 'quickshell-bar: qmllint is required but not installed\n' >&2
	exit 1
}
[ -f "$qml_import_path/Quickshell/qmldir" ] || {
	printf 'quickshell-bar: Quickshell QML modules not found under %s\n' "$qml_import_path" >&2
	exit 1
}

# A hand-written qmldir switches off the one Quickshell would generate, so every
# type in a directory must be listed in that directory's qmldir.
qml_files=$(find "$bar_dir" -name '*.qml' -type f | sort)
[ -n "$qml_files" ] || {
	printf 'quickshell-bar: no QML files under %s\n' "$bar_dir" >&2
	exit 1
}
for file in $qml_files; do
	[ "$file" = "$bar_dir/shell.qml" ] && continue
	dir=$(dirname -- "$file")
	name=$(basename -- "$file" .qml)
	[ -f "$dir/qmldir" ] || {
		printf 'quickshell-bar: %s has no qmldir\n' "${dir#"$repo_root"/}" >&2
		exit 1
	}
	grep -Eq "(^| )$name 1.0 $name.qml\$" "$dir/qmldir" || {
		printf 'quickshell-bar: %s is missing from %s/qmldir\n' "$name.qml" "${dir#"$repo_root"/}" >&2
		exit 1
	}
done

qml_status=0
# shellcheck disable=SC2086 # the file list is newline-separated paths without spaces
qml_report=$(cd "$bar_dir" && "$qmllint_command" -I "$qml_import_path" -I . $qml_files 2>&1) || qml_status=$?
# PanelWindow is registered through an interface type, so qmllint warns that
# it is not creatable; every other warning (a misspelt property) fails.
unexpected=$(printf '%s\n' "$qml_report" | grep -E '^(Warning|Error):' | grep -v 'Type PanelWindow is not creatable' || true)
if [ "$qml_status" -ne 0 ] || [ -n "$unexpected" ]; then
	printf '%s\n' "$qml_report" >&2
	printf '%s\n' 'quickshell-bar: qmllint reported errors in the bar.' >&2
	exit 1
fi

printf '%s\n' 'quickshell-bar tests passed.'
