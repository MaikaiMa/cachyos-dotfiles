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

for name in Colors Theme Clock; do
	grep -Eq "(^| )$name 1.0 $name.qml\$" "$bar_dir/qmldir" || {
		printf 'quickshell-bar: %s.qml is missing from qmldir\n' "$name" >&2
		exit 1
	}
done

qml_status=0
qml_report=$(cd "$bar_dir" && "$qmllint_command" -I "$qml_import_path" -I . ./*.qml 2>&1) || qml_status=$?
# PanelWindow is registered through an interface type, so qmllint warns that
# it is not creatable; every other warning (a misspelt property) fails.
unexpected=$(printf '%s\n' "$qml_report" | grep -E '^(Warning|Error):' | grep -v 'Type PanelWindow is not creatable' || true)
if [ "$qml_status" -ne 0 ] || [ -n "$unexpected" ]; then
	printf '%s\n' "$qml_report" >&2
	printf '%s\n' 'quickshell-bar: qmllint reported errors in the bar.' >&2
	exit 1
fi

printf '%s\n' 'quickshell-bar tests passed.'
