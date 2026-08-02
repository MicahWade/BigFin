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

	// Extend PATH for standalone Go execution
	homeDir, _ := os.UserHomeDir()
	currentPath := os.Getenv("PATH")
	os.Setenv("PATH", currentPath+":/tmp/go_bin/go/bin:/usr/local/go/bin:"+homeDir+"/go/bin:"+homeDir+"/.local/bin")

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

	qmlPath, _ := filepath.Abs("ui/qml/main.qml")
	log.Printf("[INFO] Loading Kirigami spatial UI entrypoint from: %s\n", qmlPath)
	if _, err := os.Stat(qmlPath); os.IsNotExist(err) {
		log.Fatalf("[ERROR] QML main template missing at path: %s\n", qmlPath)
	}

	log.Println("[READY] Bigfin backend environment initialized. Launching QML TV window...")

	var binPath string
	var args []string

	if qmlBin, err := exec.LookPath("qmlscene"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, "-name", "bigfin", qmlPath}
	} else if qmlBin, err := exec.LookPath("qml6"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, "-name", "bigfin", qmlPath}
	} else if qmlBin, err := exec.LookPath("qml"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		binPath = qmlBin
		args = []string{qmlBin, "-name", "bigfin", qmlPath}
	} else if pyBin, err := exec.LookPath("python3"); err == nil && isNativePyQtAvailable(pyBin) {
		log.Printf("[INFO] Launching QML UI via native host Qt engine: %s\n", pyBin)
		binPath = pyBin
		args = []string{pyBin, "-c", `import sys, os
from PyQt6.QtGui import QGuiApplication
from PyQt6.QtQml import QQmlApplicationEngine

app = QGuiApplication(sys.argv)
app.setApplicationName("bigfin")
app.setDesktopFileName("bigfin")

engine = QQmlApplicationEngine()
qml_dir = os.path.dirname(os.path.abspath(sys.argv[1]))
engine.addImportPath(qml_dir)
engine.load(sys.argv[1])
if not engine.rootObjects():
    sys.exit(1)
sys.exit(app.exec())
`, qmlPath}
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
		args = append(args, "--command=qmlscene", "org.kde.Sdk", "-name", "bigfin", qmlPath)
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
