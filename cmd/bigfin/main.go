package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"
	"os/exec"
	"path/filepath"

	"bigfin/pkg/jellyfin"
	"bigfin/pkg/player"
)

func main() {
	serverURL := flag.String("server", "http://localhost:8096", "Jellyfin Server URL")
	username := flag.String("user", "", "Jellyfin Username")
	password := flag.String("password", "", "Jellyfin Password")
	flag.Parse()

	fmt.Println("==================================================")
	fmt.Println(" Bigfin - Native Jellyfin Client for Plasma Bigscreen")
	fmt.Println("==================================================")

	client := jellyfin.NewClient(*serverURL)
	log.Printf("[INFO] Initialized Jellyfin client for server: %s\n", *serverURL)

	// Verify System Info
	ctx := context.Background()
	info, err := client.GetSystemInfo(ctx)
	if err != nil {
		log.Printf("[WARN] Public system info check: %v (Server may require direct auth)\n", err)
	} else {
		log.Printf("[SUCCESS] Connected to server '%s' (Version: %s)\n", info.ServerName, info.Version)
	}

	// Authenticate if credentials supplied
	if *username != "" {
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

	var qmlCmd *exec.Cmd
	if qmlBin, err := exec.LookPath("qmlscene"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		qmlCmd = exec.Command(qmlBin, qmlPath)
	} else if qmlBin, err := exec.LookPath("qml6"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		qmlCmd = exec.Command(qmlBin, qmlPath)
	} else if qmlBin, err := exec.LookPath("qml"); err == nil {
		log.Printf("[INFO] Launching QML UI via system binary: %s\n", qmlBin)
		qmlCmd = exec.Command(qmlBin, qmlPath)
	} else {
		log.Println("[INFO] Native qmlscene binary not found; falling back to Flatpak org.kde.Sdk environment...")
		qmlCmd = exec.Command("flatpak", "run",
			"--socket=wayland",
			"--socket=x11",
			"--device=dri",
			"--share=network",
			"--filesystem=host",
			"--command=qmlscene",
			"org.kde.Sdk",
			qmlPath,
		)
	}

	qmlCmd.Env = append(os.Environ(), "QT_QPA_PLATFORM=wayland;xcb")
	qmlCmd.Stdout = os.Stdout
	qmlCmd.Stderr = os.Stderr
	if err := qmlCmd.Run(); err != nil {
		log.Printf("[WARN] QML application finished: %v\n", err)
	}
}
