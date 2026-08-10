#!/bin/bash
# Bigfin Launcher Script for Linux Desktop / Fedora GNOME / KDE Plasma Bigscreen

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Extend PATH so desktop environment launcher can locate Go toolchain & binaries
export PATH="$PATH:/usr/lib64/qt6/bin:/home/linuxbrew/.linuxbrew/bin:/tmp/go_bin/go/bin:/usr/local/go/bin:$HOME/go/bin:$HOME/.local/bin:$HOME/.local/go/bin"

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

# Auto-update Bigfin by pulling new commits from remote repository
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log_msg "[INFO] Checking for auto-updates (pulling latest git version)..."
    BEFORE_REV=$(git rev-parse HEAD 2>/dev/null || echo "")
    if git pull --ff-only >/dev/null 2>&1 || git pull >/dev/null 2>&1; then
        AFTER_REV=$(git rev-parse HEAD 2>/dev/null || echo "")
        if [ -n "$BEFORE_REV" ] && [ "$BEFORE_REV" != "$AFTER_REV" ]; then
            log_msg "[SUCCESS] Pulled new version (${BEFORE_REV:0:7} -> ${AFTER_REV:0:7}). Rebuilding binary..."
            NEED_REBUILD=1
        else
            log_msg "[INFO] Already up to date."
        fi
    else
        log_msg "[WARN] Could not pull remote updates (offline or local modifications present)."
    fi
fi

# Auto-rebuild binary if missing or if Go source files have been updated
NEED_REBUILD=${NEED_REBUILD:-0}
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
    elif [ -f "$HOME/.local/go/bin/go" ]; then
        "$HOME/.local/go/bin/go" build -o "$SCRIPT_DIR/bin/bigfin_app" ./cmd/bigfin || true
    fi
fi

# Ensure desktop icon and launcher entry exist
mkdir -p ~/.local/share/applications ~/.local/share/pixmaps ~/.local/share/icons/hicolor/256x256/apps
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

log_msg "[INFO] Executing Bigfin app..."

export PYTHONUNBUFFERED=1

if command -v python3 >/dev/null 2>&1 && python3 -c "from PyQt6.QtQml import QQmlApplicationEngine" 2>/dev/null; then
    exec python3 -c "import sys, os, json, time
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, qInstallMessageHandler, QtMsgType

log_file_path = '$LOG_FILE'

def qt_message_handler(mode, context, message):
    prefix = '[QML LOG]'
    if mode == QtMsgType.QtWarningMsg:
        prefix = '[QML WARN]'
    elif mode == QtMsgType.QtCriticalMsg or mode == QtMsgType.QtFatalMsg:
        prefix = '[QML ERROR]'
    ts = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime())
    line = f'{ts} {prefix} {message}\n'
    sys.stderr.write(line)
    sys.stderr.flush()
    try:
        with open(log_file_path, 'a', encoding='utf-8') as f:
            f.write(line)
    except Exception:
        pass

qInstallMessageHandler(qt_message_handler)

config_dir = os.path.expanduser('~/.config/bigfin')
config_file = os.path.join(config_dir, 'sessions.json')

class SessionBridge(QObject):
    @pyqtSlot(result=str)
    def loadSessionsJson(self):
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    return f.read()
        except Exception as e:
            print('[SESSION] Load error:', e)
        return '{\"activeSessionId\":\"\",\"sessions\":[]}'

    @pyqtSlot(str, str, str, str, str, str, str)
    def saveSession(self, serverUrl, serverName, serverVersion, userId, username, accessToken, password=''):
        try:
            os.makedirs(config_dir, exist_ok=True)
            data = {'activeSessionId': '', 'sessions': []}
            if os.path.exists(config_file):
                try:
                    with open(config_file, 'r', encoding='utf-8') as f:
                        data = json.load(f)
                except Exception:
                    pass
            sess_id = f'{userId}_{int(time.time()*1000)}'
            sessions = data.get('sessions', [])
            updated = [s for s in sessions if s.get('userId') != userId or s.get('serverUrl') != serverUrl]
            new_sess = {
                'id': sess_id,
                'serverUrl': serverUrl,
                'serverName': serverName,
                'serverVersion': serverVersion,
                'userId': userId,
                'username': username,
                'accessToken': accessToken,
                'password': password,
                'lastUsed': time.strftime('%Y-%m-%dT%H:%M:%SZ', time.gmtime())
            }
            updated.insert(0, new_sess)
            data['sessions'] = updated
            data['activeSessionId'] = sess_id
            with open(config_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2)
            print(f'[SESSION] Successfully saved session for {username} at {serverUrl}')
        except Exception as e:
            print('[SESSION] Save error:', e)

    @pyqtSlot(str, result=bool)
    def switchSession(self, sessId):
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                data['activeSessionId'] = sessId
                with open(config_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2)
                return True
        except Exception as e:
            print('[SESSION] Switch error:', e)
        return False

    @pyqtSlot(str)
    def deleteSession(self, sessId):
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                sessions = [s for s in data.get('sessions', []) if s.get('id') != sessId]
                data['sessions'] = sessions
                if data.get('activeSessionId') == sessId:
                    data['activeSessionId'] = sessions[0]['id'] if sessions else ''
                with open(config_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2)
        except Exception as e:
            print('[SESSION] Delete error:', e)

    @pyqtSlot()
    def logoutActiveSession(self):
        try:
            if os.path.exists(config_file):
                with open(config_file, 'r', encoding='utf-8') as f:
                    data = json.load(f)
                data['activeSessionId'] = ''
                with open(config_file, 'w', encoding='utf-8') as f:
                    json.dump(data, f, indent=2)
        except Exception as e:
            print('[SESSION] Logout error:', e)

    @pyqtSlot(str, result=str)
    def getCachedImage(self, url):
        return url

    @pyqtSlot(str, str, str, int)
    def reportPlaybackStart(self, serverUrl, token, itemId, positionSec):
        pass

    @pyqtSlot(str, str, str, int, bool, str)
    def reportPlaybackProgress(self, serverUrl, token, itemId, positionSec, isPaused, eventName):
        pass

    @pyqtSlot(str, str, str, int)
    def reportPlaybackStopped(self, serverUrl, token, itemId, positionSec):
        pass

    @pyqtSlot(result=str)
    def checkForUpdates(self):
        try:
            import subprocess
            res = subprocess.run(['git', 'pull'], capture_output=True, text=True, timeout=15)
            if res.returncode == 0:
                out = res.stdout.strip()
                if 'Already up to date' in out or 'Already up-to-date' in out:
                    return 'Already up to date.'
                return f'Auto-updated: {out}'
            else:
                return f'Notice: {res.stderr.strip() or res.stdout.strip()}'
        except Exception as e:
            return f'Update error: {str(e)}'

app = QGuiApplication(sys.argv)
app.setApplicationName('bigfin')
app.setDesktopFileName('bigfin')

engine = QQmlApplicationEngine()
bridge = SessionBridge()
engine.rootContext().setContextProperty('SessionBridge', bridge)

qml_path = '$SCRIPT_DIR/ui/qml/main.qml'
engine.addImportPath('$SCRIPT_DIR/ui/qml')
engine.load(qml_path)
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())
" "$@" >> "$LOG_FILE" 2>&1
elif [ -f "$SCRIPT_DIR/bin/bigfin_app" ]; then
    exec "$SCRIPT_DIR/bin/bigfin_app" "$@" >> "$LOG_FILE" 2>&1
else
    log_msg "[ERROR] No runtime environment found."
    exit 1
fi
