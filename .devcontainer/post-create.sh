#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

echo "====================================="
sudo apt update
sudo apt upgrade -y

echo "====================================="
echo "Setting up permissions for config and local directories..."
sudo chown $(id -u):$(id -g) \
    ~/.config \
    ~/.config/opencode \
    ~/.local \
    ~/.local/share \
    ~/.local/share/opencode

# Ensure expected tools are installed
echo "====================================="
TOOLS=(
    "vim"
    "less"
    "git"
    "direnv"
)
echo "Ensuring required tools are installed: ${TOOLS[*]}..."
TOOLS_TO_INSTALL=()
for tool in "${TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        TOOLS_TO_INSTALL+=("$tool")
    fi
done
if [ ${#TOOLS_TO_INSTALL[@]} -gt 0 ]; then
    echo "Installing missing tools: ${TOOLS_TO_INSTALL[*]}..."
    sudo apt install -y "${TOOLS_TO_INSTALL[@]}"
else
    echo "All required tools are already installed."
fi

# Set up direnv
if [ -f ~/.bashrc ] && ! grep -q 'direnv hook bash' ~/.bashrc; then
    echo "====================================="
    echo 'Enabling direnv for bash...'
    echo '# Enable direnv' >> ~/.bashrc
    echo 'eval "$(direnv hook bash)"' >> ~/.bashrc
fi
if [ -f ~/.zshrc ] && ! grep -q 'direnv hook zsh' ~/.zshrc; then
    echo "====================================="
    echo 'Enabling direnv for zsh...'
    echo '# Enable direnv' >> ~/.zshrc
    echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc
fi

# Create .envrc to use Nix flakes
if [ ! -f ".envrc" ]; then
    echo "====================================="
    echo 'Creating .envrc to use Nix flakes...'
    echo 'use flake . --impure' >> .envrc
fi
if [ ! -f ~/.config/nix/nix.conf ] || ! grep -q 'experimental-features = nix-command flakes' ~/.config/nix/nix.conf; then
    echo "====================================="
    echo 'Enabling Nix experimental features...'
    mkdir -p ~/.config/nix
    echo 'experimental-features = nix-command flakes' >> ~/.config/nix/nix.conf
fi

# if NIX_DEV_CONTAINER_POST_CREATE_BASH_CMD is set, execute it
if [ -f "$SCRIPT_DIR/../.env" ]; then
    echo "====================================="
    echo "Loading .env file from $SCRIPT_DIR/../.env"
    . "$SCRIPT_DIR/../.env"
    if [ -n "${NIX_DEV_CONTAINER_POST_CREATE_BASH_CMD:-}" ]; then
        echo "Running post-create bash command from .env: $NIX_DEV_CONTAINER_POST_CREATE_BASH_CMD"
        if ! bash -c "$NIX_DEV_CONTAINER_POST_CREATE_BASH_CMD"; then
            echo "Error: Post-create bash command failed. Please check the command and try again."
            exit 1
        fi
    fi
    echo "====================================="
    echo ""
fi

# Allow direnv
echo "====================================="
echo "Allowing direnv for the project..."
direnv allow
