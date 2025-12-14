#!/usr/bin/env bash
set -euo pipefail

# Packages to install
packages=(
    fish tmux chezmoi starship lazygit yazi bat exa fzf fd ripgrep zoxide git-delta tldr
)

# Install missing packages
missing_packages=()
for pkg in "${packages[@]}"; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        missing_packages+=("$pkg")
    fi
done

if (( ${#missing_packages[@]} > 0 )); then
    sudo pacman -Sy --noconfirm "${missing_packages[@]}"
fi

# Ensure fish is in /etc/shells
FISH_PATH="$(command -v fish)"
if ! grep -qFx "$FISH_PATH" /etc/shells; then
    echo "$FISH_PATH" | sudo tee -a /etc/shells >/dev/null
fi

# Set fish as default shell if not already
if [ "$SHELL" != "$FISH_PATH" ]; then
    chsh -s "$FISH_PATH"
fi

# Install TPM if missing
TPM_DIR="$HOME/.tmux/plugins/tpm"
if [ ! -d "$TPM_DIR" ]; then
    git clone https://github.com/tmux-plugins/tpm "$TPM_DIR"
fi

# Apply tmux plugins by sourcing tmux.conf inside tmux (safe, idempotent)
tmux_conf="$HOME/.tmux.conf"
if [ -f "$tmux_conf" ]; then
    # Only attempt if tmux is installed
    tmux start-server
    # Install plugins inside a temporary tmux session
    tmux new-session -d -s _tpm_install \
        "run-shell '$TPM_DIR/bin/install_plugins && exit'"
    tmux kill-session -t _tpm_install
fi
