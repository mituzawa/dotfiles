#!/bin/bash
# setup.sh
# Script to create symbolic links for dotfiles in the home directory

set -e

DOTFILES_DIR="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="$HOME"

# List of targets to link, as "<path inside dotfiles>:<path inside home>".
# When the two sides share the same path, ":<path inside home>" may be omitted.
TARGETS=(
    ".bashrc"
    ".profile"
    ".gitconfig"
    ".clang-format"
    ".vimrc"
    ".vim"
    "bin"
    "nvim:.config/nvim"
)

link_file() {
    local src="$DOTFILES_DIR/$1"   # Link target (dotfiles side)
    local dst="$HOME_DIR/$2"       # Link source (home side)
    local org="${dst}_ORG"

    # Skip if the file does not exist in dotfiles
    if [ ! -e "$src" ]; then
        echo "SKIP (not found in dotfiles): $1"
        return
    fi

    # Create the parent directory when linking below $HOME (e.g. ~/.config)
    mkdir -p "$(dirname "$dst")"

    # If a regular file/directory exists at the destination (not a symlink)
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        if [ -e "$org" ]; then
            # _ORG already exists; skip backup and proceed to link
            echo "SKIP BACKUP (_ORG already exists): $1"
        else
            # Back up with _ORG suffix, preserving timestamps and permissions
            echo "BACKUP: $dst -> $org"
            cp -ap "$dst" "$org"
        fi
        rm -rf "$dst"
    fi

    # Remove existing symlink if present
    if [ -L "$dst" ]; then
        rm "$dst"
    fi

    echo "LINK: $dst -> $src"
    ln -s "$src" "$dst"
}

for target in "${TARGETS[@]}"; do
    # Split "src:dst"; fall back to src when no destination is given
    src_path="${target%%:*}"
    dst_path="${target#*:}"
    link_file "$src_path" "$dst_path"
done

echo ""
echo "Done."
