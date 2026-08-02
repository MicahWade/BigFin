#!/bin/bash
# Bigfin Launcher Script for Linux Desktop / Fedora GNOME / KDE Plasma Bigscreen

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Extend PATH so desktop environment launcher can locate Go toolchain & binaries
export PATH="$PATH:/tmp/go_bin/go/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin"

LOG_FILE="/tmp/bigfin_launch.log"

log_msg() {
    echo "$@" | tee -a "$LOG_FILE"
}

log_msg "=================================================="
log_msg "[LAUNCH LOG] Timestamp: $(date '+%Y-%m-%d %H:%M:%S')"
log_msg "[LAUNCH LOG] Shell PID: $$ | Parent PID: $PPID | Command: $0 $@"
log_msg "[LAUNCH LOG] DESKTOP_STARTUP_ID: ${DESKTOP_STARTUP_ID:-<unset>}"
log_msg "[LAUNCH LOG] XDG_ACTIVATION_TOKEN: ${XDG_ACTIVATION_TOKEN:-<unset>}"
log_msg "[LAUNCH LOG] WAYLAND_DISPLAY: ${WAYLAND_DISPLAY:-<unset>} | DISPLAY: ${DISPLAY:-<unset>}"
log_msg "[LAUNCH LOG] XDG_CURRENT_DESKTOP: ${XDG_CURRENT_DESKTOP:-<unset>}"
log_msg "=================================================="

# Prevent multiple concurrent instances when launched via KDE Runner / Desktop entry
LOCK_FILE="/tmp/bigfin.lock"
if command -v flock >/dev/null 2>&1; then
    exec 200>"$LOCK_FILE"
    if ! flock -n 200; then
        log_msg "[INFO] Bigfin is already running (instance lock active)."
        exit 0
    fi
fi

IS_SETUP=0
if [ "$1" = "--setup" ]; then
    IS_SETUP=1
    shift
fi

WM_CLASS="bigfin"
if ! command -v qmlscene >/dev/null 2>&1 && ! command -v qml6 >/dev/null 2>&1 && ! command -v qml >/dev/null 2>&1; then
    if python3 -c "from PyQt6.QtQml import QQmlApplicationEngine" 2>/dev/null; then
        WM_CLASS="bigfin"
    elif command -v flatpak >/dev/null 2>&1; then
        WM_CLASS="org.kde.Sdk"
    fi
fi

# Auto-rebuild binary if missing or if Go source files have been updated
NEED_REBUILD=0
if [ ! -f "$SCRIPT_DIR/bin/bigfin_app" ]; then
    NEED_REBUILD=1
elif [ -n "$(find "$SCRIPT_DIR/cmd" "$SCRIPT_DIR/pkg" -type f -name "*.go" -newer "$SCRIPT_DIR/bin/bigfin_app" 2>/dev/null)" ]; then
    NEED_REBUILD=1
fi

if [ "$NEED_REBUILD" -eq 1 ]; then
    log_msg "[INFO] Source code changed or binary missing. Rebuilding Bigfin binary..."
    mkdir -p "$SCRIPT_DIR/bin"
    if command -v go >/dev/null 2>&1; then
        go build -o "$SCRIPT_DIR/bin/bigfin_app" ./cmd/bigfin || true
    elif [ -f "/tmp/go_bin/go/bin/go" ]; then
        /tmp/go_bin/go/bin/go build -o "$SCRIPT_DIR/bin/bigfin_app" ./cmd/bigfin || true
    fi
fi

# Ensure desktop icon and launcher entry exist
if [ ! -f ~/.local/share/applications/bigfin.desktop ] || [ "$IS_SETUP" -eq 1 ]; then
    mkdir -p ~/.local/share/applications ~/.local/share/pixmaps ~/.local/share/icons/hicolor/256x256/apps
    if [ -f "$SCRIPT_DIR/Logo.png" ]; then
        cp "$SCRIPT_DIR/Logo.png" ~/.local/share/icons/hicolor/256x256/apps/bigfin.png 2>/dev/null || true
        cp "$SCRIPT_DIR/Logo.png" ~/.local/share/pixmaps/bigfin.png 2>/dev/null || true
    fi

    cat << EOF > ~/.local/share/applications/bigfin.desktop
[Desktop Entry]
Type=Application
Name=Bigfin
Comment=Native 10-Foot Jellyfin Media Client (Go Engine)
Exec=$SCRIPT_DIR/bin/bigfin_app
Path=$SCRIPT_DIR
Icon=$SCRIPT_DIR/Logo.png
Terminal=false
Categories=AudioVideo;Player;TV;
StartupWMClass=$WM_CLASS
SingleMainWindow=true
StartupNotify=true
EOF

    # Remove legacy desktop entry if present so KDE Plasma has exactly ONE desktop launcher
    rm -f ~/.local/share/applications/org.bigfin.client.desktop ~/.local/share/icons/hicolor/256x256/apps/org.bigfin.client.png ~/.local/share/pixmaps/org.bigfin.client.png 2>/dev/null || true

    if [ "$IS_SETUP" -eq 1 ]; then
        # Refresh KDE desktop application cache only during explicit setup
        update-desktop-database ~/.local/share/applications 2>/dev/null || kbuildsycoca6 2>/dev/null || kbuildsycoca5 2>/dev/null || true
        if [ $# -eq 0 ]; then
            log_msg "[INFO] Desktop setup complete."
            exit 0
        fi
    fi
fi

log_msg "[INFO] Executing Bigfin app binary from script..."

# Launch compiled binary if present, otherwise launch via Go
if [ -f "$SCRIPT_DIR/bin/bigfin_app" ]; then
    exec "$SCRIPT_DIR/bin/bigfin_app" "$@"
elif command -v go >/dev/null 2>&1; then
    exec go run ./cmd/bigfin "$@"
elif [ -f "/tmp/go_bin/go/bin/go" ]; then
    exec /tmp/go_bin/go/bin/go run ./cmd/bigfin "$@"
else
    log_msg "[ERROR] Neither compiled binary nor Go runtime was found."
    exit 1
fi
