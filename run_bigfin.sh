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

# Priority system python paths over brew Qt overrides if needed
export PATH=/usr/bin:$PATH
export PYTHONPATH=""
export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH

# Launch Bigfin UI from project root
cd "$SCRIPT_DIR"
exec python3 preview_ui.py "$@"
