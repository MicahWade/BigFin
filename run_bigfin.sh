#!/bin/bash
# Bigfin Launcher Script for Linux Desktop / Fedora GNOME / KDE Plasma Bigscreen

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Extend PATH so desktop environment launcher can locate Go toolchain & binaries
export PATH="$PATH:/tmp/go_bin/go/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin"

echo "=================================================="
echo " Starting Bigfin Client (Linux Desktop)"
echo "=================================================="

# Ensure desktop icon and launcher entry exist
if [ ! -f ~/.local/share/applications/bigfin.desktop ]; then
    mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications ~/.local/share/pixmaps
    if [ -f "$SCRIPT_DIR/Logo.png" ]; then
        cp "$SCRIPT_DIR/Logo.png" ~/.local/share/icons/hicolor/256x256/apps/bigfin.png 2>/dev/null || true
        cp "$SCRIPT_DIR/Logo.png" ~/.local/share/pixmaps/bigfin.png 2>/dev/null || true
    fi

    cat << EOF > ~/.local/share/applications/bigfin.desktop
[Desktop Entry]
Type=Application
Name=Bigfin
Comment=Native 10-Foot Jellyfin Media Client
Exec=$SCRIPT_DIR/run_bigfin.sh
Path=$SCRIPT_DIR
Icon=bigfin
Terminal=false
Categories=AudioVideo;Player;TV;
EOF
fi

# 4. Launch compiled binary if present, otherwise launch via Go
if [ -f "$SCRIPT_DIR/bin/bigfin_app" ]; then
    exec "$SCRIPT_DIR/bin/bigfin_app" "$@"
elif command -v go >/dev/null 2>&1; then
    exec go run ./cmd/bigfin "$@"
elif [ -f "/tmp/go_bin/go/bin/go" ]; then
    exec /tmp/go_bin/go/bin/go run ./cmd/bigfin "$@"
else
    echo "[ERROR] Neither compiled binary nor Go runtime was found."
    exit 1
fi
