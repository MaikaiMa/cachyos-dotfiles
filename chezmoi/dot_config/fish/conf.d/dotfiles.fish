# Make the chezmoi-deployed helpers in ~/.local/bin callable from Fish.
fish_add_path --global --path ~/.local/bin

# Git, chezmoi and other tools fall back to vi, which is not installed.
set -gx EDITOR vim
set -gx VISUAL vim
