#!/usr/bin/env fish
# Fish entry point for the POSIX validation implementation.
set script_dir (cd (dirname (status filename)); and pwd)
exec sh "$script_dir/validate.sh" $argv
