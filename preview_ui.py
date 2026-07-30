#!/usr/bin/python3
import sys
import os
import json
import urllib.request
import urllib.parse
import datetime
import threading

# Filter out Linuxbrew site-packages to prevent Qt library ABI collisions with system Kirigami
sys.path = [p for p in sys.path if "linuxbrew" not in p]

from PyQt6.QtCore import QUrl, QObject, pyqtSlot, pyqtSignal
from PyQt6.QtGui import QGuiApplication, QIcon
from PyQt6.QtQml import QQmlApplicationEngine

class SessionBridge(QObject):
    sessionsUpdated = pyqtSignal()
    activeSessionChanged = pyqtSignal()

    def __init__(self):
        super().__init__()
        self.config_dir = os.path.expanduser("~/.config/bigfin")
        os.makedirs(self.config_dir, exist_ok=True)
        self.config_file = os.path.join(self.config_dir, "sessions.json")
        self._store = {"activeSessionId": "", "sessions": []}
        self.load_sessions_from_file()

    def load_sessions_from_file(self):
        if os.path.exists(self.config_file):
            try:
                with open(self.config_file, "r", encoding="utf-8") as f:
                    self._store = json.load(f)
            except Exception as e:
                print(f"[SESSION BRIDGE] Error reading sessions file: {e}")

    @pyqtSlot(result=str)
    def loadSessionsJson(self):
        self.load_sessions_from_file()
        return json.dumps(self._store)

    @pyqtSlot(str, str, str, str, str, str, result=str)
    def saveSession(self, server_url, server_name, server_version, user_id, username, access_token):
        clean_url = server_url.rstrip("/")
        session_id = f"{clean_url}_{user_id}".replace("//", "_").replace(":", "_").replace("/", "_")
        session = {
            "id": session_id,
            "serverUrl": clean_url,
            "serverName": server_name or "Jellyfin Server",
            "serverVersion": server_version or "10.8.0",
            "userId": user_id,
            "username": username,
            "accessToken": access_token,
            "deviceId": "bigfin-plasma-tv-01",
            "lastUsed": datetime.datetime.now().isoformat()
        }
        sessions = [s for s in self._store.get("sessions", []) if s.get("id") != session_id]
        sessions.insert(0, session)
        self._store["sessions"] = sessions
        self._store["activeSessionId"] = session_id

        self._save_to_disk()
        self.sessionsUpdated.emit()
        self.activeSessionChanged.emit()
        return json.dumps(session)

    @pyqtSlot(str, result=bool)
    def switchSession(self, session_id):
        sessions = self._store.get("sessions", [])
        found = False
        for s in sessions:
            if s.get("id") == session_id:
                s["lastUsed"] = datetime.datetime.now().isoformat()
                found = True
                break
        if found:
            self._store["activeSessionId"] = session_id
            self._save_to_disk()
            self.sessionsUpdated.emit()
            self.activeSessionChanged.emit()
            return True
        return False

    @pyqtSlot(str, result=str)
    def deleteSession(self, session_id):
        sessions = [s for s in self._store.get("sessions", []) if s.get("id") != session_id]
        self._store["sessions"] = sessions
        if self._store.get("activeSessionId") == session_id:
            self._store["activeSessionId"] = sessions[0]["id"] if len(sessions) > 0 else ""
        self._save_to_disk()
        self.sessionsUpdated.emit()
        self.activeSessionChanged.emit()
        return json.dumps(self._store)

    @pyqtSlot(result=bool)
    def logoutActiveSession(self):
        self._store["activeSessionId"] = ""
        self._save_to_disk()
        self.activeSessionChanged.emit()
        return True

    @pyqtSlot(result=str)
    def getActiveSessionJson(self):
        active_id = self._store.get("activeSessionId", "")
        for s in self._store.get("sessions", []):
            if s.get("id") == active_id:
                return json.dumps(s)
        return ""

    @pyqtSlot(str, result=str)
    def getCachedImage(self, remote_url):
        if not remote_url or not remote_url.startswith("http"):
            return remote_url or ""
        import hashlib
        url_hash = hashlib.md5(remote_url.encode('utf-8')).hexdigest()
        cache_dir = os.path.expanduser("~/.cache/bigfin/images")
        os.makedirs(cache_dir, exist_ok=True)
        local_path = os.path.join(cache_dir, f"{url_hash}.jpg")
        if os.path.exists(local_path) and os.path.getsize(local_path) > 0:
            return "file://" + local_path

        def _download():
            try:
                req = urllib.request.Request(remote_url, headers={
                    "User-Agent": "Bigfin/1.0",
                    "Accept": "image/jpeg,image/png,*/*"
                })
                with urllib.request.urlopen(req, timeout=5) as resp:
                    data = resp.read()
                    with open(local_path + ".tmp", "wb") as f:
                        f.write(data)
                    os.replace(local_path + ".tmp", local_path)
            except Exception:
                pass

        threading.Thread(target=_download, daemon=True).start()
        return remote_url

    @pyqtSlot(str, str, str, float)
    def reportPlaybackStart(self, server_url, access_token, item_id, position_seconds=0.0):
        def _send():
            try:
                url = f"{server_url}/Sessions/Playing"
                payload = json.dumps({
                    "ItemId": item_id,
                    "PositionTicks": int(position_seconds * 10000000),
                    "IsPaused": False,
                    "EventName": "start"
                }).encode('utf-8')
                req = urllib.request.Request(url, data=payload, headers={
                    "Content-Type": "application/json",
                    "X-Emby-Authorization": f'MediaBrowser Client="Bigfin", Device="Plasma Bigscreen", DeviceId="bigfin-01", Version="1.0.0", Token="{access_token}"'
                })
                urllib.request.urlopen(req, timeout=3)
                print(f"[SESSION BRIDGE] Reported PlaybackStart to Jellyfin for item {item_id}")
            except Exception as e:
                print(f"[SESSION BRIDGE ERROR] reportPlaybackStart fail: {e}")
        threading.Thread(target=_send, daemon=True).start()

    @pyqtSlot(str, str, str, float)
    @pyqtSlot(str, str, str, float, bool)
    @pyqtSlot(str, str, str, float, bool, str)
    def reportPlaybackProgress(self, server_url, access_token, item_id, position_seconds, is_paused=False, event_name="timeupdate"):
        def _send():
            try:
                url = f"{server_url}/Sessions/Playing/Progress"
                payload = json.dumps({
                    "ItemId": item_id,
                    "PositionTicks": int(position_seconds * 10000000),
                    "IsPaused": is_paused,
                    "EventName": event_name
                }).encode('utf-8')
                req = urllib.request.Request(url, data=payload, headers={
                    "Content-Type": "application/json",
                    "X-Emby-Authorization": f'MediaBrowser Client="Bigfin", Device="Plasma Bigscreen", DeviceId="bigfin-01", Version="1.0.0", Token="{access_token}"'
                })
                urllib.request.urlopen(req, timeout=3)
            except Exception as e:
                pass
        threading.Thread(target=_send, daemon=True).start()

    @pyqtSlot(str, str, str, float)
    def reportPlaybackStopped(self, server_url, access_token, item_id, position_seconds):
        def _send():
            try:
                url = f"{server_url}/Sessions/Playing/Stopped"
                payload = json.dumps({
                    "ItemId": item_id,
                    "PositionTicks": int(position_seconds * 10000000),
                    "EventName": "stop"
                }).encode('utf-8')
                req = urllib.request.Request(url, data=payload, headers={
                    "Content-Type": "application/json",
                    "X-Emby-Authorization": f'MediaBrowser Client="Bigfin", Device="Plasma Bigscreen", DeviceId="bigfin-01", Version="1.0.0", Token="{access_token}"'
                })
                urllib.request.urlopen(req, timeout=3)
                print(f"[SESSION BRIDGE] Reported PlaybackStopped to Jellyfin for item {item_id} at {position_seconds}s")
            except Exception as e:
                print(f"[SESSION BRIDGE ERROR] reportPlaybackStopped fail: {e}")
        threading.Thread(target=_send, daemon=True).start()

    def _save_to_disk(self):
        try:
            with open(self.config_file, "w", encoding="utf-8") as f:
                json.dump(self._store, f, indent=2)
        except Exception as e:
            print(f"[SESSION BRIDGE] Error saving sessions file: {e}")

def main():
    print("==================================================")
    print(" Bigfin Media Client - Native 10-Foot UI Launcher")
    print("==================================================")
    
    app = QGuiApplication(sys.argv)
    app.setOrganizationName("Bigfin")
    app.setOrganizationDomain("bigfin.org")
    app.setApplicationName("org.bigfin.client")
    app.setDesktopFileName("org.bigfin.client")

    base_dir = os.path.dirname(os.path.abspath(__file__))
    logo_path = os.path.join(base_dir, 'Logo.png')
    if os.path.exists(logo_path):
        app.setWindowIcon(QIcon(logo_path))

    engine = QQmlApplicationEngine()
    
    # Detect Plasma Bigscreen vs regular Linux desktop
    desktop_env = (os.environ.get("XDG_CURRENT_DESKTOP", "") + " " + os.environ.get("DESKTOP_SESSION", "")).lower()
    is_plasma_bigscreen = "bigscreen" in desktop_env or "plasma-bigscreen" in desktop_env
    engine.rootContext().setContextProperty("isPlasmaBigscreenEnv", is_plasma_bigscreen)

    # Expose SessionBridge instance to QML context
    session_bridge = SessionBridge()
    engine.rootContext().setContextProperty("SessionBridge", session_bridge)
    
    qml_dir = os.path.join(base_dir, 'ui', 'qml')
    engine.addImportPath(qml_dir)
    for path in ['/usr/lib64/qt6/qml', '/usr/lib/qt6/qml', '/usr/lib64/qt5/qml', '/usr/lib/qt5/qml']:
        if os.path.exists(path):
            engine.addImportPath(path)
            
    target_file = 'tst_VisualNavigation.qml' if len(sys.argv) > 1 and sys.argv[1] == '--test' else 'main.qml'
    qml_file = os.path.join(qml_dir, target_file)
    print(f"[*] Loading QML target: {qml_file}")
    
    engine.load(QUrl.fromLocalFile(qml_file))

    if not engine.rootObjects():
        print("[!] QML Engine failed to load root window.")
        sys.exit(-1)

    print("[SUCCESS] Bigfin 10-Foot TV UI active!")
    print("[HINT] Controls: Arrow keys (D-Pad), Enter (Select), Space (Play/Toggle), Esc/Backspace (Back), D (HUD)")
    sys.exit(app.exec())

if __name__ == '__main__':
    main()

