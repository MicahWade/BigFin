package jellyfin

import (
	"encoding/json"
	"strings"
	"testing"
)

func TestBuildImageURL(t *testing.T) {
	client := NewClient("http://jellyfin.local:8096")
	imgURL := client.BuildImageURL("item-123", "Primary", 400, 600)

	expectedBase := "http://jellyfin.local:8096/Items/item-123/Images/Primary"
	if !strings.HasPrefix(imgURL, expectedBase) {
		t.Errorf("expected URL to start with %s, got %s", expectedBase, imgURL)
	}
	if !strings.Contains(imgURL, "fillWidth=400") || !strings.Contains(imgURL, "fillHeight=600") || !strings.Contains(imgURL, "format=WEBP") {
		t.Errorf("missing expected query parameters or WEBP format in image URL: %s", imgURL)
	}
}

func TestConstructStreamURL(t *testing.T) {
	client := NewClient("http://jellyfin.local:8096")
	client.AccessToken = "secret-token-123"

	videoStreamURL := client.ConstructStreamURL("movie-456", "source-789", "Movie")
	expectedVideo := "http://jellyfin.local:8096/Videos/movie-456/stream?"
	if !strings.HasPrefix(videoStreamURL, expectedVideo) {
		t.Errorf("expected video stream URL to start with %s, got %s", expectedVideo, videoStreamURL)
	}
	if !strings.Contains(videoStreamURL, "api_key=secret-token-123") {
		t.Errorf("missing api_key token parameter: %s", videoStreamURL)
	}

	audioStreamURL := client.ConstructStreamURL("song-456", "source-789", "Audio")
	expectedAudio := "http://jellyfin.local:8096/Audio/song-456/stream?"
	if !strings.HasPrefix(audioStreamURL, expectedAudio) {
		t.Errorf("expected audio stream URL to start with %s, got %s", expectedAudio, audioStreamURL)
	}
}

func TestBaseItemJSONParsing(t *testing.T) {
	jsonContent := `{
		"Id": "abc-123",
		"Name": "Blade Runner 2049",
		"Type": "Movie",
		"Overview": "A dystopian sci-fi masterpiece",
		"ProductionYear": 2017,
		"CommunityRating": 8.0,
		"IsFolder": false,
		"UserData": {
			"PlaybackPositionTicks": 100000,
			"PlayCount": 2,
			"IsFavorite": true,
			"Played": false
		}
	}`

	var item BaseItem
	err := json.Unmarshal([]byte(jsonContent), &item)
	if err != nil {
		t.Fatalf("failed to unmarshal BaseItem JSON: %v", err)
	}

	if item.ID != "abc-123" {
		t.Errorf("expected ID 'abc-123', got '%s'", item.ID)
	}
	if item.Name != "Blade Runner 2049" {
		t.Errorf("expected Name 'Blade Runner 2049', got '%s'", item.Name)
	}
	if item.ProductionYear != 2017 {
		t.Errorf("expected ProductionYear 2017, got %d", item.ProductionYear)
	}
	if !item.UserData.IsFavorite {
		t.Errorf("expected IsFavorite true")
	}
}

func TestParseServerURLs(t *testing.T) {
	input := "192.168.1.50, 10.0.0.5:8096; http://jellyfin.local:8096"
	urls := ParseServerURLs(input)

	if len(urls) != 3 {
		t.Fatalf("expected 3 URLs, got %d: %v", len(urls), urls)
	}
	if urls[0] != "http://192.168.1.50:8096" {
		t.Errorf("expected http://192.168.1.50:8096, got %s", urls[0])
	}
	if urls[1] != "http://10.0.0.5:8096" {
		t.Errorf("expected http://10.0.0.5:8096, got %s", urls[1])
	}
	if urls[2] != "http://jellyfin.local:8096" {
		t.Errorf("expected http://jellyfin.local:8096, got %s", urls[2])
	}
}
