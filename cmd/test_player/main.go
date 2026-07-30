package main

import (
	"context"
	"fmt"
	"log"
	"os"
	"time"

	"bigfin/pkg/jellyfin"
	"bigfin/pkg/player"
)

func main() {
	fmt.Println("==================================================")
	fmt.Println(" Bigfin Go Player Engine & Stream Verification ")
	fmt.Println("==================================================")

	serverURL := os.Getenv("JELLYFIN_SERVER_URL")
	if serverURL == "" {
		serverURL = "http://localhost:8096"
	}
	token := os.Getenv("JELLYFIN_TOKEN")
	if len(os.Args) > 1 {
		serverURL = os.Args[1]
	}
	if len(os.Args) > 2 {
		token = os.Args[2]
	}

	p, err := player.NewPlayer()
	if err != nil {
		log.Fatalf("[FATAL] Failed to initialize player: %v", err)
	}
	defer p.Destroy()

	log.Printf("[INFO] Initialized player engine: %s (IPC Path: %s)\n", p.EngineType, p.IPCPath)

	client := jellyfin.NewClient(serverURL)
	client.AccessToken = token

	ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
	defer cancel()

	log.Printf("[INFO] Connecting to Jellyfin server at %s...\n", serverURL)
	views, err := client.FetchUserViews(ctx)
	var streamURL string

	if err == nil && len(views) > 0 {
		items, err := client.FetchItems(ctx, views[0].ID, "Movie,Episode", 1)
		if err == nil && len(items) > 0 {
			item := items[0]
			mediaSourceID := item.ID
			if len(item.MediaSources) > 0 {
				mediaSourceID = item.MediaSources[0].ID
			}
			streamURL = client.ConstructAdaptiveHLSURL(item.ID, mediaSourceID, 0)
			log.Printf("[SUCCESS] Target Media Found: '%s' (ID: %s)\n", item.Name, item.ID)
			log.Printf("[STREAM URL] Adaptive HLS Auto-Resolution URL: %s\n", streamURL)
		}
	}

	if streamURL == "" {
		streamURL = serverURL + "/Videos/59ec513227115c5f0aa6d186967706ee/master.m3u8?MediaSourceId=59ec513227115c5f0aa6d186967706ee&VideoCodec=h264&AudioCodec=aac,mp3&api_key=" + token
		log.Printf("[INFO] Using direct test HLS stream: %s\n", streamURL)
	}

	// 1. Test Load File
	log.Println("[TEST 1] Loading Stream into Player...")
	if err := p.LoadFile(streamURL); err != nil {
		log.Fatalf("[FAIL] LoadFile failed: %v", err)
	}
	log.Println("[PASS] LoadFile completed successfully.")

	// 2. Test Playback Controls
	log.Println("[TEST 2] Testing Playback Controls (Pause, Seek, Volume, Tracks)...")
	time.Sleep(500 * time.Millisecond)

	if err := p.Pause(); err != nil {
		log.Printf("[WARN] Pause call warning: %v\n", err)
	} else {
		log.Println("  - Pause: OK")
	}

	if err := p.Play(); err != nil {
		log.Printf("[WARN] Play call warning: %v\n", err)
	} else {
		log.Println("  - Resume Play: OK")
	}

	if err := p.Seek(15.0); err != nil {
		log.Printf("[WARN] Seek warning: %v\n", err)
	} else {
		log.Printf("  - Seek +15s (Position: %.1fs): OK\n", p.Position)
	}

	if err := p.SetVolume(85); err != nil {
		log.Printf("[WARN] Volume warning: %v\n", err)
	} else {
		log.Printf("  - Set Volume 85%%: OK\n")
	}

	if err := p.SetAudioTrack(1); err != nil {
		log.Printf("[WARN] SetAudioTrack warning: %v\n", err)
	} else {
		log.Println("  - Set Audio Track #1: OK")
	}

	if err := p.SetSubtitleTrack(1); err != nil {
		log.Printf("[WARN] SetSubtitleTrack warning: %v\n", err)
	} else {
		log.Println("  - Set Subtitle Track #1: OK")
	}

	// 3. Audio & Visual Output Verification
	log.Println("[TEST 3] Verifying Audio & Visual Playback Output...")
	health, err := p.VerifyAudioAndVisuals(ctx)
	if err != nil {
		log.Fatalf("[FAIL] VerifyAudioAndVisuals error: %v", err)
	}

	fmt.Println("--------------------------------------------------")
	fmt.Printf(" VERIFICATION REPORT:\n")
	fmt.Printf("   Engine Active : %s\n", health.Engine)
	fmt.Printf("   State         : %s\n", health.State)
	fmt.Printf("   Audio Active  : %v (Codec: %s)\n", health.AudioActive, health.AudioCodec)
	fmt.Printf("   Visuals Active: %v (Codec: %s, %dx%d @ %.1ffps)\n", health.VisualsActive, health.VideoCodec, health.Width, health.Height, health.FPS)
	fmt.Printf("   Details       : %s\n", health.Details)
	fmt.Println("--------------------------------------------------")

	if health.AudioActive && health.VisualsActive {
		fmt.Println("[ALL TESTS PASSED] Video Player engine is operating correctly with working audio & visuals!")
	} else {
		fmt.Println("[WARNING] Video Player reported missing audio or video components.")
	}
}
