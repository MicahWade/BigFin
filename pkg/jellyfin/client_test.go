package jellyfin

import (
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
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

func TestPlaylistParsing(t *testing.T) {
	jsonContent := `{
		"Id": "pl-999",
		"Name": "Chill Lo-Fi Beats",
		"Type": "Playlist",
		"MediaType": "Audio",
		"ChildCount": 15,
		"Overview": "Smooth tracks for relaxing"
	}`

	var item BaseItem
	err := json.Unmarshal([]byte(jsonContent), &item)
	if err != nil {
		t.Fatalf("failed to unmarshal Playlist BaseItem: %v", err)
	}

	if item.ID != "pl-999" {
		t.Errorf("expected ID 'pl-999', got '%s'", item.ID)
	}
	if item.Type != "Playlist" {
		t.Errorf("expected Type 'Playlist', got '%s'", item.Type)
	}
	if item.ChildCount != 15 {
		t.Errorf("expected ChildCount 15, got %d", item.ChildCount)
	}
}

func TestFetchPlaylists(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/Users/user-123/Items") {
			t.Errorf("unexpected path: %s", r.URL.Path)
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}
		if r.URL.Query().Get("IncludeItemTypes") != "Playlist" {
			t.Errorf("expected IncludeItemTypes=Playlist, got %s", r.URL.Query().Get("IncludeItemTypes"))
		}
		if r.URL.Query().Get("Recursive") != "true" {
			t.Errorf("expected Recursive=true, got %s", r.URL.Query().Get("Recursive"))
		}

		resp := ItemsQueryResult{
			Items: []BaseItem{
				{ID: "pl-1", Name: "Rock Hits", Type: "Playlist", ChildCount: 10},
				{ID: "pl-2", Name: "Jazz Classics", Type: "Playlist", ChildCount: 5},
			},
			TotalRecordCount: 2,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.UserID = "user-123"

	playlists, err := client.FetchPlaylists(context.Background())
	if err != nil {
		t.Fatalf("FetchPlaylists failed: %v", err)
	}
	if len(playlists) != 2 {
		t.Fatalf("expected 2 playlists, got %d", len(playlists))
	}
	if playlists[0].Name != "Rock Hits" || playlists[1].Name != "Jazz Classics" {
		t.Errorf("unexpected playlist names: %v", playlists)
	}
}

func TestFetchPlaylistItems(t *testing.T) {
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if !strings.HasPrefix(r.URL.Path, "/Playlists/pl-1/Items") {
			t.Errorf("unexpected path: %s", r.URL.Path)
			http.Error(w, "Not found", http.StatusNotFound)
			return
		}

		resp := ItemsQueryResult{
			Items: []BaseItem{
				{ID: "song-1", Name: "Bohemian Rhapsody", Type: "Audio", RunTimeTicks: 3540000000},
			},
			TotalRecordCount: 1,
		}
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(resp)
	}))
	defer server.Close()

	client := NewClient(server.URL)
	client.UserID = "user-123"

	items, err := client.FetchPlaylistItems(context.Background(), "pl-1")
	if err != nil {
		t.Fatalf("FetchPlaylistItems failed: %v", err)
	}
	if len(items) != 1 {
		t.Fatalf("expected 1 playlist item, got %d", len(items))
	}
	if items[0].Name != "Bohemian Rhapsody" {
		t.Errorf("expected track name 'Bohemian Rhapsody', got '%s'", items[0].Name)
	}
}

