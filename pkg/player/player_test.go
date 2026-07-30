package player

import (
	"context"
	"testing"
	"time"

	"bigfin/pkg/jellyfin"
)

func TestPlayerInitialization(t *testing.T) {
	p, err := NewPlayer()
	if err != nil {
		t.Fatalf("Failed to initialize player: %v", err)
	}
	defer p.Destroy()

	if p.State != StateIdle {
		t.Errorf("Expected initial state Idle, got %s", p.State)
	}
	if p.Volume != 100 {
		t.Errorf("Expected initial volume 100, got %d", p.Volume)
	}
	if p.EngineType == "" {
		t.Errorf("Expected non-empty EngineType")
	}
}

func TestPlayerLoadAndControls(t *testing.T) {
	p, err := NewPlayer()
	if err != nil {
		t.Fatalf("Failed to initialize player: %v", err)
	}
	defer p.Destroy()

	testStreamURL := "/tmp/test_video.mp4"
	if err := p.LoadFile(testStreamURL); err != nil {
		t.Fatalf("Failed to load file: %v", err)
	}

	if p.State != StatePlaying {
		t.Errorf("Expected state Playing after LoadFile, got %s", p.State)
	}

	// Test Pause
	if err := p.Pause(); err != nil {
		t.Errorf("Pause error: %v", err)
	}
	if p.State != StatePaused {
		t.Errorf("Expected state Paused, got %s", p.State)
	}

	// Test Play / Resume
	if err := p.Play(); err != nil {
		t.Errorf("Play error: %v", err)
	}
	if p.State != StatePlaying {
		t.Errorf("Expected state Playing, got %s", p.State)
	}

	// Test TogglePause
	if err := p.TogglePause(); err != nil {
		t.Errorf("TogglePause error: %v", err)
	}
	if p.State != StatePaused {
		t.Errorf("Expected state Paused after toggle, got %s", p.State)
	}

	// Test Seek
	if err := p.Seek(10.0); err != nil {
		t.Errorf("Seek error: %v", err)
	}
	if p.Position != 10.0 {
		t.Errorf("Expected position 10.0s, got %.1fs", p.Position)
	}

	// Test Seek backwards
	if err := p.Seek(-5.0); err != nil {
		t.Errorf("Seek error: %v", err)
	}
	if p.Position != 5.0 {
		t.Errorf("Expected position 5.0s, got %.1fs", p.Position)
	}

	// Test Volume
	if err := p.SetVolume(75); err != nil {
		t.Errorf("SetVolume error: %v", err)
	}
	if p.Volume != 75 {
		t.Errorf("Expected volume 75, got %d", p.Volume)
	}

	// Test Track selection
	if err := p.SetAudioTrack(2); err != nil {
		t.Errorf("SetAudioTrack error: %v", err)
	}
	if p.AudioTrackID != 2 {
		t.Errorf("Expected AudioTrackID 2, got %d", p.AudioTrackID)
	}

	if err := p.SetSubtitleTrack(1); err != nil {
		t.Errorf("SetSubtitleTrack error: %v", err)
	}
	if p.SubtitleTrackID != 1 {
		t.Errorf("Expected SubtitleTrackID 1, got %d", p.SubtitleTrackID)
	}

	// Test Resolution Mode
	if err := p.SetResolutionMode(ResolutionAuto); err != nil {
		t.Errorf("SetResolutionMode error: %v", err)
	}
	if !p.AutoResolutionMode || p.ResolutionMode != ResolutionAuto {
		t.Errorf("Expected AutoResolutionMode true and ResolutionAuto, got %v / %s", p.AutoResolutionMode, p.ResolutionMode)
	}

	// Test Stop
	if err := p.Stop(); err != nil {
		t.Errorf("Stop error: %v", err)
	}
	if p.State != StateStopped {
		t.Errorf("Expected state Stopped, got %s", p.State)
	}
}

func TestVerifyAudioAndVisuals(t *testing.T) {
	p, err := NewPlayer()
	if err != nil {
		t.Fatalf("Failed to initialize player: %v", err)
	}
	defer p.Destroy()

	testStreamURL := "/tmp/test_video.mp4"
	if err := p.LoadFile(testStreamURL); err != nil {
		t.Fatalf("Failed to load stream: %v", err)
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	health, err := p.VerifyAudioAndVisuals(ctx)
	if err != nil {
		t.Fatalf("VerifyAudioAndVisuals error: %v", err)
	}

	t.Logf("Audio/Visual Health Details: %s", health.Details)

	if !health.AudioActive {
		t.Errorf("Expected AudioActive to be true")
	}
	if !health.VisualsActive {
		t.Errorf("Expected VisualsActive to be true")
	}
	if health.VideoCodec == "" {
		t.Errorf("Expected non-empty VideoCodec")
	}
	if health.AudioCodec == "" {
		t.Errorf("Expected non-empty AudioCodec")
	}
	if health.Width <= 0 || health.Height <= 0 {
		t.Errorf("Expected valid video resolution width & height, got %dx%d", health.Width, health.Height)
	}
}

func TestJellyfinStreamPlayback(t *testing.T) {
	serverURL := "http://100.85.125.82:8096"
	token := "0b8630ceeb2f4da6a4230bdac8f4a599"

	client := jellyfin.NewClient(serverURL)
	client.AccessToken = token

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	views, err := client.FetchUserViews(ctx)
	if err != nil {
		t.Skipf("Live Jellyfin server not reachable: %v (skipping live stream test)", err)
		return
	}

	if len(views) == 0 {
		t.Skip("No views returned from server")
		return
	}

	items, err := client.FetchItems(ctx, views[0].ID, "Movie,Episode", 1)
	if err != nil || len(items) == 0 {
		t.Skip("No items found in view")
		return
	}

	targetItem := items[0]
	mediaSourceID := targetItem.ID
	if len(targetItem.MediaSources) > 0 {
		mediaSourceID = targetItem.MediaSources[0].ID
	}
	streamURL := client.ConstructStreamURL(targetItem.ID, mediaSourceID, targetItem.Type)
	t.Logf("Testing Jellyfin HLS Stream URL: %s", streamURL)

	p, err := NewPlayer()
	if err != nil {
		t.Fatalf("Failed to create player: %v", err)
	}
	defer p.Destroy()

	if err := p.LoadFile(streamURL); err != nil {
		t.Fatalf("Failed to load Jellyfin HLS stream: %v", err)
	}

	health, err := p.VerifyAudioAndVisuals(ctx)
	if err != nil {
		t.Fatalf("Playback verification failed: %v", err)
	}

	t.Logf("[SUCCESS] Live Jellyfin Playback Verified: %s", health.Details)
	if !health.AudioActive || !health.VisualsActive {
		t.Errorf("Live Jellyfin stream verification failed. Health: %+v", health)
	}
}
