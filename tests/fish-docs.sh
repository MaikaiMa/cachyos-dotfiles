#!/bin/sh
# Validate every Markdown block marked as copyable Fish input.
set -eu

repo_root=$(
	CDPATH=
	export CDPATH
	cd -- "$(dirname -- "$0")/.."
	pwd
)

for tool in find fish mktemp sort; do
	if ! command -v "$tool" >/dev/null 2>&1; then
		printf 'Required command not found: %s\n' "$tool" >&2
		exit 1
	fi
done

snippet_dir=$(mktemp -d)
cleanup() {
	rm -rf -- "$snippet_dir"
}
trap cleanup EXIT HUP INT TERM

find "$repo_root/docs" -type f -name '*.md' -print |
	{
		printf '%s\n' "$repo_root/README.md"
		cat
	} |
	sort |
	while IFS= read -r markdown_file; do
		inside_fish_block=false
		block_number=0
		snippet_file=$snippet_dir/snippet.fish

		while IFS= read -r line || [ -n "$line" ]; do
			case $line in
			'```fish')
				if [ "$inside_fish_block" = true ]; then
					printf 'Nested Fish block in %s\n' "$markdown_file" >&2
					exit 1
				fi
				inside_fish_block=true
				block_number=$((block_number + 1))
				: >"$snippet_file"
				;;
			'```')
				if [ "$inside_fish_block" = true ]; then
					if ! fish -n "$snippet_file"; then
						printf 'Invalid Fish block %s in %s\n' \
							"$block_number" "$markdown_file" >&2
						exit 1
					fi
					inside_fish_block=false
				fi
				;;
			*)
				if [ "$inside_fish_block" = true ]; then
					printf '%s\n' "$line" >>"$snippet_file"
				fi
				;;
			esac
		done <"$markdown_file"

		if [ "$inside_fish_block" = true ]; then
			printf 'Unclosed Fish block in %s\n' "$markdown_file" >&2
			exit 1
		fi
	done

printf '%s\n' 'Documented Fish commands passed syntax validation.'
