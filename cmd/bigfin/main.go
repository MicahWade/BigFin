package main

import (
	"context"
	"flag"
	"io"
	"log"
	"os"
	"os/exec"
	"path/filepath"
	"syscall"
	"time"

	"bigfin/pkg/autoupdate"
	"bigfin/pkg/jellyfin"
	"bigfin/pkg/player"
)

func main() {
	logFilePath := "/tmp/bigfin_launch.log"
	logFile, err := os.OpenFile(logFilePath, os.O_CREATE|os.O_WRONLY|os.O_APPEND, 0666)
	if err == nil {
		defer logFile.Close()
		multiWriter := io.MultiWriter(os.Stdout, logFile)
		log.SetOutput(multiWriter)
	}

	// Perform auto-update by pulling latest git version
	autoupdate.ExecuteAutoUpdate()

	// Extend PATH for standalone Go execution and Qt6 QML tools
	homeDir, _ := os.UserHomeDir()
	currentPath := os.Getenv("PATH")
	os.Setenv("PATH", currentPath+":/usr/lib64/qt6/bin:/tmp/go_bin/go/bin:/usr/local/go/bin:"+homeDir+"/go/bin:"+homeDir+"/.local/bin")

	serverURL := flag.String("server", "http://localhost:8096", "Jellyfin Server URL")
	username := flag.String("user", "", "Jellyfin Username")
	password := flag.String("password", "", "Jellyfin Password")
	flag.Parse()

	log.Printf("[GO LAUNCH LOG] PID: %d | PPID: %d | Args: %v\n", os.Getpid(), os.Getppid(), os.Args)
	log.Printf("[GO LAUNCH LOG] DESKTOP_STARTUP_ID=%s | WAYLAND_DISPLAY=%s | DISPLAY=%s\n",
		os.Getenv("DESKTOP_STARTUP_ID"), os.Getenv("WAYLAND_DISPLAY"), os.Getenv("DISPLAY"))

	lockFilePath := "/tmp/bigfin_go.lock"
	lockFd, err := os.OpenFile(lockFilePath, os.O_CREATE|os.O_RDWR, 0666)
	if err == nil {
		if err := syscall.Flock(int(lockFd.Fd()), syscall.LOCK_EX|syscall.LOCK_NB); err != nil {
			log.Printf("[INFO] Bigfin Go backend process is already running (PID %d blocked by %s). Exiting.\n", os.Getpid(), lockFilePath)
			os.Exit(0)
		}
	}

	client := jellyfin.NewClient(*serverURL)
	log.Printf("[INFO] Initialized Jellyfin client for server: %s\n", *serverURL)

	// Verify System Info in background so startup is instant
	go func() {
		ctx, cancel := context.WithTimeout(context.Background(), 3*time.Second)
		defer cancel()
		info, err := client.GetSystemInfo(ctx)
		if err != nil {
			log.Printf("[WARN] Public system info check: %v (Server may require direct auth)\n", err)
		} else {
			log.Printf("[SUCCESS] Connected to server '%s' (Version: %s)\n", info.ServerName, info.Version)
		}
	}()

	// Authenticate if credentials supplied
	if *username != "" {
		ctx := context.Background()
		log.Printf("[INFO] Authenticating user '%s'...\n", *username)
		authResult, err := client.AuthenticateByName(ctx, *username, *password)
		if err != nil {
			log.Fatalf("[ERROR] Authentication failed: %v\n", err)
		}
		tokenSnippet := authResult.AccessToken
		if len(tokenSnippet) > 8 {
			tokenSnippet = tokenSnippet[:8]
		}
		log.Printf("[SUCCESS] Authenticated! User ID: %s, AccessToken: %s...\n", authResult.User.ID, tokenSnippet)

		// Fetch libraries
		views, err := client.FetchUserViews(ctx)
		if err != nil {
			log.Printf("[WARN] Could not fetch views: %v\n", err)
		} else {
			log.Printf("[SUCCESS] Loaded %d user library views:\n", len(views))
			for i, v := range views {
				log.Printf("  [%d] %s (Type: %s, ID: %s)\n", i+1, v.Name, v.Type, v.ID)
			}
		}
	}

	// Initialize MPV Player Subsystem
	p, err := player.NewPlayer()
	if err != nil {
		log.Printf("[WARN] libmpv initialization warning: %v\n", err)
	} else {
		log.Println("[SUCCESS] libmpv media player engine initialized with HW acceleration.")
		defer p.Destroy()
	}

	execDir := "."
	if exePath, err := os.Executable(); err == nil {
		execDir = filepath.Dir(exePath)
	}
	qmlPath := filepath.Join(execDir, "../ui/qml/main.qml")
	if _, err := os.Stat(qmlPath); os.IsNotExist(err) {
		qmlPath, _ = filepath.Abs("ui/qml/main.qml")
	}
	log.Printf("[INFO] Loading Kirigami spatial UI entrypoint from: %s\n", qmlPath)
	if _, err := os.Stat(qmlPath); os.IsNotExist(err) {
		log.Fatalf("[ERROR] QML main template missing at path: %s\n", qmlPath)
	}
	log.Println("[READY] Bigfin backend environment initialized. Launching QML TV window...")

	log.Println("[INFO] Launching QML UI natively via CGo Qt6 Engine...")
	ret := launchNativeQtQml(qmlPath)
	if ret == 0 {
		log.Println("[INFO] Native Qt QML session ended cleanly.")
		return
	}
	log.Printf("[WARN] Native CGo Qt6 launcher returned code %d. Attempting fallbacks...\n", ret)

	var binPath string
	var args []string

	if pyBin, err := exec.LookPath("python3"); err == nil && isNativePyQtAvailable(pyBin) {
		log.Printf("[INFO] Launching QML UI via native Python PyQt6 engine with SessionBridge: %s\n", pyBin)
		binPath = pyBin
		pythonScript := `import sys, os, json, time
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine
from PyQt6.QtCore import QObject, pyqtSlot, qInstallMessageHandler, QtMsgType

log_file_path = "/tmp/bigfin_launch.log"

def qt_message_handler(mode, context, message):
    prefix = "[QML LOG]"
    if mode == QtMsgType.QtWarningMsg:
        prefix = "[QML WARN]"
    elif mode == QtMsgType.QtCriticalMsg or mode == QtMsgType.QtFatalMsg:
        prefix = "[QML ERROR]"
    ts = time.strftime("%Y-%m-%d %H:%M:%S", time.localtime())
    line = f"{ts} {prefix} {message}\n"
    sys.stderr.write(line)
    sys.stderr.flush()
    try:
        with open(log_file_path, "a", encoding="utf-8") as f:
            f.write(line)
    except Exception:
        pass

qInstallMessageHandler(qt_message_handler)

config_dir = os.path.expanduser("~/.config/bigfin")
config_file = os.path.join(config_dir, "sessions.json")

class SessionBridge(QObject):
    @pyqtSlot(result=str)
    def loadSessionsJson(self):
        try:
            if os.path.exists(config_file):
                with open(config_file, "r", encoding="utf-8") as f:
                    return f.read()
        except Exception as e:
            print("[SESSION] Load error:", e)
        return '{"activeSessionId":"","sessions":[]}'

    @pyqtSlot(str, str, str, str, str, str, str)
    def saveSession(self, serverUrl, serverName, serverVersion, userId, username, accessToken, password=''):
        try:
            os.makedirs(config_dir, exist_ok=True)
            data = {"activeSessionId": "", "sessions": []}
            if os.path.exists(config_file):
                try:
                    with open(config_file, "r", encoding="utf-8") as f:
                        data = json.load(f)
                except Exception:
                    pass
            sess_id = f"{userId}_{int(time.time()*1000)}"
            sessions = data.get("sessions", [])
            updated = [s for s in sessions if s.get("userId") != userId or s.get("serverUrl") != serverUrl]
            new_sess = {
                "id": sess_id,
                "serverUrl": serverUrl,
                "serverName": serverName,
                "serverVersion": serverVersion,
                "userId": userId,
                "username": username,
                "accessToken": accessToken,
                "password": password,
                "lastUsed": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            }
            updated.insert(0, new_sess)
            data["sessions"] = updated
            data["activeSessionId"] = sess_id
            with open(config_file, "w", encoding="utf-8") as f:
                json.dump(data, f, indent=2)
            print(f"[SESSION] Successfully saved session for {username} at {serverUrl}")
        except Exception as e:
            print("[SESSION] Save error:", e)

    @pyqtSlot(str, result=bool)
    def switchSession(self, sessId):
        try:
            if os.path.exists(config_file):
                with open(config_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                data["activeSessionId"] = sessId
                with open(config_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
                return True
        except Exception as e:
            print("[SESSION] Switch error:", e)
        return False

    @pyqtSlot(str)
    def deleteSession(self, sessId):
        try:
            if os.path.exists(config_file):
                with open(config_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                sessions = [s for s in data.get("sessions", []) if s.get("id") != sessId]
                data["sessions"] = sessions
                if data.get("activeSessionId") == sessId:
                    data["activeSessionId"] = sessions[0]["id"] if sessions else ""
                with open(config_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
        except Exception as e:
            print("[SESSION] Delete error:", e)

    @pyqtSlot()
    def logoutActiveSession(self):
        try:
            if os.path.exists(config_file):
                with open(config_file, "r", encoding="utf-8") as f:
                    data = json.load(f)
                data["activeSessionId"] = ""
                with open(config_file, "w", encoding="utf-8") as f:
                    json.dump(data, f, indent=2)
        except Exception as e:
            print("[SESSION] Logout error:", e)

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
            res = subprocess.run(["git", "pull"], capture_output=True, text=True, timeout=15)
            if res.returncode == 0:
                out = res.stdout.strip()
                if "Already up to date" in out or "Already up-to-date" in out:
                    return "Already up to date."
                return f"Auto-updated: {out}"
            else:
                return f"Notice: {res.stderr.strip() or res.stdout.strip()}"
        except Exception as e:
            return f"Update error: {str(e)}"

app = QGuiApplication(sys.argv)
app.setApplicationName("bigfin")
app.setDesktopFileName("bigfin")

engine = QQmlApplicationEngine()
bridge = SessionBridge()
engine.rootContext().setContextProperty("SessionBridge", bridge)

qml_dir = os.path.dirname(os.path.abspath(sys.argv[1]))
engine.addImportPath(qml_dir)
engine.load(sys.argv[1])
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())
`
		args = []string{pyBin, "-c", pythonScript, qmlPath}
	} else if qmlBin, err := exec.LookPath("qmlscene"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, qmlPath}
	} else if qmlBin, err := exec.LookPath("qmlscene-qt6"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, qmlPath}
	} else if qmlBin, err := exec.LookPath("qml6"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, qmlPath}
	} else if qmlBin, err := exec.LookPath("qml"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, qmlPath}
	} else if flatpakBin, err := exec.LookPath("flatpak"); err == nil {
		log.Println("[INFO] Native qmlscene binary not found; executing Flatpak org.kde.Sdk environment...")
		binPath = flatpakBin
		args = []string{"flatpak", "run",
			"--socket=wayland",
			"--socket=x11",
			"--device=dri",
			"--share=network",
			"--filesystem=host",
		}
		if startupID := os.Getenv("DESKTOP_STARTUP_ID"); startupID != "" {
			args = append(args, "--env=DESKTOP_STARTUP_ID="+startupID)
		}
		if token := os.Getenv("XDG_ACTIVATION_TOKEN"); token != "" {
			args = append(args, "--env=XDG_ACTIVATION_TOKEN="+token)
		}
		if wdisp := os.Getenv("WAYLAND_DISPLAY"); wdisp != "" {
			args = append(args, "--env=WAYLAND_DISPLAY="+wdisp)
		}
		if disp := os.Getenv("DISPLAY"); disp != "" {
			args = append(args, "--env=DISPLAY="+disp)
		}
		args = append(args, "--command=qmlscene", "org.kde.Sdk", qmlPath)
	} else {
		log.Fatalf("[ERROR] No suitable QML runtime or Flatpak environment found.")
	}

	env := append(os.Environ(), "QT_QPA_PLATFORM=wayland;xcb", "RESOURCE_NAME=bigfin")
	log.Printf("[GO LAUNCH LOG] Executing binary '%s' with args: %v\n", binPath, args)
	if err := syscall.Exec(binPath, args, env); err != nil {
		log.Printf("[WARN] syscall.Exec fallback to exec.Command: %v\n", err)
		qmlCmd := exec.Command(binPath, args[1:]...)
		qmlCmd.Env = env
		qmlCmd.Stdout = log.Writer()
		qmlCmd.Stderr = log.Writer()
		_ = qmlCmd.Run()
	}
}

func isNativePyQtAvailable(pythonBin string) bool {
	cmd := exec.Command(pythonBin, "-c", "from PyQt6.QtQml import QQmlApplicationEngine")
	return cmd.Run() == nil
}
