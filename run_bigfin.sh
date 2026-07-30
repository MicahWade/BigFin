#!/bin/bash
# Bigfin Launcher Script for Linux Desktop / KDE Plasma Bigscreen

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=================================================="
echo " Starting Bigfin Client (Linux Desktop)"
echo "=================================================="

# Ensure desktop file & icon are registered for taskbar
mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications ~/.local/share/pixmaps
if [ -f "$SCRIPT_DIR/Logo.png" ]; then
    cp "$SCRIPT_DIR/Logo.png" ~/.local/share/icons/hicolor/256x256/apps/org.bigfin.client.png 2>/dev/null || true
    cp "$SCRIPT_DIR/Logo.png" ~/.local/share/icons/hicolor/256x256/apps/bigfin.png 2>/dev/null || true
    cp "$SCRIPT_DIR/Logo.png" ~/.local/share/pixmaps/org.bigfin.client.png 2>/dev/null || true
    cp "$SCRIPT_DIR/Logo.png" ~/.local/share/pixmaps/bigfin.png 2>/dev/null || true
fi

cat << EOF > ~/.local/share/applications/org.bigfin.client.desktop
[Desktop Entry]
Type=Application
Name=Bigfin
Comment=Native 10-Foot Jellyfin Media Client
Exec=$SCRIPT_DIR/run_bigfin.sh
Icon=org.bigfin.client
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=org.bigfin.client
EOF

cat << EOF > ~/.local/share/applications/bigfin.desktop
[Desktop Entry]
Type=Application
Name=Bigfin
Comment=Native 10-Foot Jellyfin Media Client
Exec=$SCRIPT_DIR/run_bigfin.sh
Icon=bigfin
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=bigfin
EOF

cd "$SCRIPT_DIR"

# Launch compiled binary if present, otherwise launch via Go
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
