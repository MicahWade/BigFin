#!/bin/bash
# Bigfin Launcher Script for Fedora Wayland / KDE Plasma / Linux Desktop

echo "=================================================="
echo " Starting Bigfin Client (Fedora Wayland Desktop)"
echo "=================================================="

# Ensure desktop file & icon are registered for taskbar
mkdir -p ~/.local/share/icons/hicolor/256x256/apps ~/.local/share/applications ~/.local/share/pixmaps
cp Logo.png ~/.local/share/icons/hicolor/256x256/apps/org.bigfin.client.png 2>/dev/null || true
cp Logo.png ~/.local/share/icons/hicolor/256x256/apps/bigfin.png 2>/dev/null || true
cp Logo.png ~/.local/share/pixmaps/org.bigfin.client.png 2>/dev/null || true
cp Logo.png ~/.local/share/pixmaps/bigfin.png 2>/dev/null || true

cat << 'EOF' > ~/.local/share/applications/org.bigfin.client.desktop
[Desktop Entry]
Type=Application
Name=Bigfin
Comment=Native 10-Foot Jellyfin Media Client
Exec=/home/Bitpoke/Documents/Bigfin/run_bigfin.sh
Icon=org.bigfin.client
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=org.bigfin.client
EOF

cat << 'EOF' > ~/.local/share/applications/bigfin.desktop
[Desktop Entry]
Type=Application
Name=Bigfin
Comment=Native 10-Foot Jellyfin Media Client
Exec=/home/Bitpoke/Documents/Bigfin/run_bigfin.sh
Icon=bigfin
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=bigfin
EOF

# Ensure system Fedora Python & Qt6 libraries take priority over Linuxbrew Qt packages
export PATH=/usr/bin:$PATH
export PYTHONPATH=""
export LD_LIBRARY_PATH=/usr/lib64:$LD_LIBRARY_PATH

# Launch Bigfin interface using system Python
/usr/bin/python3 preview_ui.py "$@"
