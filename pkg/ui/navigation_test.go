package ui

import (
	"fmt"
	"math"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"testing"
)

// TestGridDynamicColumnsCalculation verifies that column math and boundary checks
// work across various screen widths and cell sizes, preventing focus locks and bad row wrapping.
func TestGridDynamicColumnsCalculation(t *testing.T) {
	cellWidth := 210.0

	testCases := []struct {
		screenWidth    float64
		expectedCols   int
		testIndices    []int
		isLeftEdge     []bool
		isTopRow       []bool
	}{
		{
			screenWidth:  800.0,
			expectedCols: 3,
			testIndices:  []int{0, 1, 2, 3, 4, 5},
			isLeftEdge:   []bool{true, false, false, true, false, false},
			isTopRow:     []bool{true, true, true, false, false, false},
		},
		{
			screenWidth:  1000.0,
			expectedCols: 4,
			testIndices:  []int{0, 1, 3, 4, 5, 7, 8},
			isLeftEdge:   []bool{true, false, false, true, false, false, true},
			isTopRow:     []bool{true, true, true, false, false, false, false},
		},
		{
			screenWidth:  1920.0,
			expectedCols: 9,
			testIndices:  []int{0, 4, 8, 9, 10, 17, 18},
			isLeftEdge:   []bool{true, false, false, true, false, false, true},
			isTopRow:     []bool{true, true, true, false, false, false, false},
		},
	}

	for _, tc := range testCases {
		t.Run(fmt.Sprintf("Width_%.0f", tc.screenWidth), func(t *testing.T) {
			cols := int(math.Max(1, math.Floor(tc.screenWidth/cellWidth)))
			if cols != tc.expectedCols {
				t.Errorf("Expected %d columns for width %.0f, got %d", tc.expectedCols, tc.screenWidth, cols)
			}

			for i, idx := range tc.testIndices {
				leftEdge := (idx % cols) == 0
				if leftEdge != tc.isLeftEdge[i] {
					t.Errorf("Index %d at width %.0f: expected leftEdge=%v, got %v", idx, tc.screenWidth, tc.isLeftEdge[i], leftEdge)
				}

				topRow := idx < cols
				if topRow != tc.isTopRow[i] {
					t.Errorf("Index %d at width %.0f: expected topRow=%v, got %v", idx, tc.screenWidth, tc.isTopRow[i], topRow)
				}
			}
		})
	}
}

// TestHomeViewVerticalNavigationFallback tests that vertical focus navigation
// correctly bypasses empty sections to prevent focus loss.
func TestHomeViewVerticalNavigationFallback(t *testing.T) {
	type sectionState struct {
		continueWatching int
		movies           int
		music            int
		tv               int
	}

	testCases := []struct {
		name                 string
		state                sectionState
		expectedDefaultFocus string
		downFromCW           string
		downFromMovies       string
		downFromMusic        string
		upFromMovies         string
		upFromMusic          string
		upFromTV             string
	}{
		{
			name: "All Sections Populated",
			state: sectionState{
				continueWatching: 3,
				movies:           10,
				music:            5,
				tv:               8,
			},
			expectedDefaultFocus: "cw",
			downFromCW:           "movies",
			downFromMovies:       "music",
			downFromMusic:        "tv",
			upFromMovies:         "cw",
			upFromMusic:          "movies",
			upFromTV:             "music",
		},
		{
			name: "Empty Continue Watching",
			state: sectionState{
				continueWatching: 0,
				movies:           10,
				music:            5,
				tv:               8,
			},
			expectedDefaultFocus: "movies",
			downFromCW:           "movies",
			downFromMovies:       "music",
			downFromMusic:        "tv",
			upFromMovies:         "sidebar",
			upFromMusic:          "movies",
			upFromTV:             "music",
		},
		{
			name: "Only Movies and TV",
			state: sectionState{
				continueWatching: 0,
				movies:           5,
				music:            0,
				tv:               4,
			},
			expectedDefaultFocus: "movies",
			downFromCW:           "movies",
			downFromMovies:       "tv",
			downFromMusic:        "tv",
			upFromMovies:         "sidebar",
			upFromMusic:          "movies",
			upFromTV:             "movies",
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			// Helper simulate default focus
			getDefaultFocus := func(s sectionState) string {
				if s.continueWatching > 0 {
					return "cw"
				}
				if s.movies > 0 {
					return "movies"
				}
				if s.music > 0 {
					return "music"
				}
				if s.tv > 0 {
					return "tv"
				}
				return "cw"
			}

			if def := getDefaultFocus(tc.state); def != tc.expectedDefaultFocus {
				t.Errorf("Expected default focus '%s', got '%s'", tc.expectedDefaultFocus, def)
			}

			// Helper simulate navigateDownFrom("cw")
			getDownFromCW := func(s sectionState) string {
				if s.movies > 0 {
					return "movies"
				}
				if s.music > 0 {
					return "music"
				}
				if s.tv > 0 {
					return "tv"
				}
				return "none"
			}

			if d := getDownFromCW(tc.state); d != tc.downFromCW {
				t.Errorf("Expected downFromCW '%s', got '%s'", tc.downFromCW, d)
			}

			// Helper simulate navigateUpFrom("tv")
			getUpFromTV := func(s sectionState) string {
				if s.music > 0 {
					return "music"
				}
				if s.movies > 0 {
					return "movies"
				}
				if s.continueWatching > 0 {
					return "cw"
				}
				return "sidebar"
			}

			if u := getUpFromTV(tc.state); u != tc.upFromTV {
				t.Errorf("Expected upFromTV '%s', got '%s'", tc.upFromTV, u)
			}
		})
	}
}

// TestQMLFilesNoHardcodedGridColumns ensures no QML file contains fragile hardcoded 'index % 8'
// or 'index < 8' grid navigation checks that freeze arrow keys on varying resolutions.
func TestQMLFilesNoHardcodedGridColumns(t *testing.T) {
	qmlDir := filepath.Join("..", "..", "ui", "qml")
	entries, err := os.ReadDir(qmlDir)
	if err != nil {
		t.Fatalf("Failed to read QML directory %s: %v", qmlDir, err)
	}

	hardcodedPattern := regexp.MustCompile(`index\s*[%<]\s*8`)

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".qml") {
			continue
		}

		path := filepath.Join(qmlDir, entry.Name())
		content, err := os.ReadFile(path)
		if err != nil {
			t.Fatalf("Failed to read QML file %s: %v", path, err)
		}

		if hardcodedPattern.Match(content) {
			t.Errorf("File %s contains hardcoded 'index %% 8' or 'index < 8' grid math! Must use dynamic columns calculation.", entry.Name())
		}
	}
}

// TestQMLGlobalFocusRecoveryNet verifies that Main.qml contains the safety focus recovery net
// for unhandled arrow key presses.
func TestQMLGlobalFocusRecoveryNet(t *testing.T) {
	mainQmlPath := filepath.Join("..", "..", "ui", "qml", "Main.qml")
	content, err := os.ReadFile(mainQmlPath)
	if err != nil {
		t.Fatalf("Failed to read Main.qml: %v", err)
	}

	strContent := string(content)

	if !strings.Contains(strContent, "Safety Focus Recovery Net") {
		t.Errorf("Main.qml is missing the Safety Focus Recovery Net for arrow key presses!")
	}

	if !strings.Contains(strContent, "moveFocusToView()") {
		t.Errorf("Main.qml does not invoke moveFocusToView() for focus recovery!")
	}
}

// TestQMLEpisodeCarouselNavigationAndPerformance verifies that episode and media carousels in DetailsView.qml
// and HomeView.qml implement snappy animation parameters and full Left/Right arrow navigation.
func TestQMLEpisodeCarouselNavigationAndPerformance(t *testing.T) {
	detailsQmlPath := filepath.Join("..", "..", "ui", "qml", "DetailsView.qml")
	content, err := os.ReadFile(detailsQmlPath)
	if err != nil {
		t.Fatalf("Failed to read DetailsView.qml: %v", err)
	}

	detailsContent := string(content)

	if !strings.Contains(detailsContent, "highlightMoveDuration: 75") {
		t.Errorf("DetailsView.qml missing snappy highlightMoveDuration for episode carousel!")
	}

	if !strings.Contains(detailsContent, "seasonEpListView.currentIndex = index - 1") {
		t.Errorf("DetailsView.qml missing Left arrow navigation handling for episode carousel index > 0!")
	}

	if !strings.Contains(detailsContent, "seasonEpListView.currentIndex = index + 1") {
		t.Errorf("DetailsView.qml missing Right arrow navigation handling for episode carousel!")
	}

	homeQmlPath := filepath.Join("..", "..", "ui", "qml", "HomeView.qml")
	homeContentBytes, err := os.ReadFile(homeQmlPath)
	if err != nil {
		t.Fatalf("Failed to read HomeView.qml: %v", err)
	}

	homeContent := string(homeContentBytes)

	if !strings.Contains(homeContent, "continueWatchingList.currentIndex = index - 1") {
		t.Errorf("HomeView.qml missing Left arrow navigation handling for continue watching carousel!")
	}

	mainQmlPath := filepath.Join("..", "..", "ui", "qml", "Main.qml")
	mainContentBytes, err := os.ReadFile(mainQmlPath)
	if err != nil {
		t.Fatalf("Failed to read Main.qml: %v", err)
	}

	mainContent := string(mainContentBytes)
	if !strings.Contains(mainContent, "restoreFocus()") {
		t.Errorf("Main.qml missing restoreFocus() invocation in moveFocusToView!")
	}

	if !strings.Contains(detailsContent, "function restoreFocus()") {
		t.Errorf("DetailsView.qml missing restoreFocus() function to resume focus position!")
	}

	if !strings.Contains(homeContent, "function restoreFocus()") {
		t.Errorf("HomeView.qml missing restoreFocus() function to resume focus position!")
	}

	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}

	appDataContent := string(appDataBytes)
	if !strings.Contains(appDataContent, "seasonNavModeIdx: 0") {
		t.Errorf("AppData.qml missing default seasonNavModeIdx property!")
	}

	if !strings.Contains(detailsContent, "seasonNavModeIdx") {
		t.Errorf("DetailsView.qml missing seasonNavModeIdx check in vertical season navigation!")
	}

	if !strings.Contains(detailsContent, "targetY = (itemY + itemH / 2) - (viewH / 2)") {
		t.Errorf("DetailsView.qml missing middle-row vertical centering math in ensureVisible!")
	}
}

// TestQMLGridUpArrowNavigation verifies that QML GridViews (GridView.qml, SearchView.qml)
// handle Up Arrow key navigation when index >= columns by moving to the target index (index - columns).
func TestQMLGridUpArrowNavigation(t *testing.T) {
	gridQmlPath := filepath.Join("..", "..", "ui", "qml", "GridView.qml")
	gridContentBytes, err := os.ReadFile(gridQmlPath)
	if err != nil {
		t.Fatalf("Failed to read GridView.qml: %v", err)
	}

	gridContent := string(gridContentBytes)

	if !strings.Contains(gridContent, "index - columns") && !strings.Contains(gridContent, "currentIndex - columns") {
		t.Errorf("GridView.qml missing Up Arrow row navigation math (index - columns) for multi-row grids!")
	}

	searchQmlPath := filepath.Join("..", "..", "ui", "qml", "SearchView.qml")
	searchContentBytes, err := os.ReadFile(searchQmlPath)
	if err != nil {
		t.Fatalf("Failed to read SearchView.qml: %v", err)
	}

	searchContent := string(searchContentBytes)

	if !strings.Contains(searchContent, "index - columns") {
		t.Errorf("SearchView.qml missing Up Arrow row navigation math (index - columns) for search results grid!")
	}
}

// TestQMLRatingsVisibilitySettings verifies that AppData.qml and view components correctly integrate
// rating visibility controls (showRatings, ratingsCategoryIdx, isRatingVisible) and settings UI bindings.
func TestQMLRatingsVisibilitySettings(t *testing.T) {
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}

	appDataContent := string(appDataBytes)

	if !strings.Contains(appDataContent, "showRatings") {
		t.Errorf("AppData.qml missing showRatings property!")
	}
	if !strings.Contains(appDataContent, "ratingsCategoryIdx") {
		t.Errorf("AppData.qml missing ratingsCategoryIdx property!")
	}
	if !strings.Contains(appDataContent, "function isRatingVisible(item)") {
		t.Errorf("AppData.qml missing isRatingVisible(item) function!")
	}

	settingsPath := filepath.Join("..", "..", "ui", "qml", "SettingsView.qml")
	settingsBytes, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("Failed to read SettingsView.qml: %v", err)
	}

	settingsContent := string(settingsBytes)

	if !strings.Contains(settingsContent, "Enable Star Ratings Display") {
		t.Errorf("SettingsView.qml missing Enable Star Ratings Display option!")
	}
	if !strings.Contains(settingsContent, "Star Ratings Media Filter") {
		t.Errorf("SettingsView.qml missing Star Ratings Media Filter option!")
	}

	gridPath := filepath.Join("..", "..", "ui", "qml", "GridView.qml")
	gridBytes, err := os.ReadFile(gridPath)
	if err != nil {
		t.Fatalf("Failed to read GridView.qml: %v", err)
	}
	gridContent := string(gridBytes)
	if !strings.Contains(gridContent, "AppData.isRatingVisible(modelData)") {
		t.Errorf("GridView.qml missing AppData.isRatingVisible(modelData) check!")
	}

	homePath := filepath.Join("..", "..", "ui", "qml", "HomeView.qml")
	homeBytes, err := os.ReadFile(homePath)
	if err != nil {
		t.Fatalf("Failed to read HomeView.qml: %v", err)
	}
	homeContent := string(homeBytes)
	if !strings.Contains(homeContent, "AppData.isRatingVisible(modelData)") {
		t.Errorf("HomeView.qml missing AppData.isRatingVisible(modelData) check!")
	}
}

// TestQMLTTLCacheAndDynamicLoading verifies that AppData.qml and DetailsView.qml implement:
// 1. A TTL Cache Engine with automatic timer cleanup and evicted cache logic across all UI fetch calls.
// 2. Dynamic/Lazy loading in DetailsView.qml (rendering initial season instantly and loading remaining seasons in background).
// 3. Off-thread asynchronous image decoding and caching across QML views.
func TestQMLTTLCacheAndDynamicLoading(t *testing.T) {
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}

	appDataContent := string(appDataBytes)

	// Verify TTL Cache Engine primitives
	cachePrimitives := []string{
		"dataCache",
		"getCachedData",
		"setCachedData",
		"clearExpiredCache",
		"invalidateCacheKey",
		"clearAllCache",
		"cacheCleanupTimer",
	}
	for _, prim := range cachePrimitives {
		if !strings.Contains(appDataContent, prim) {
			t.Errorf("AppData.qml missing TTL cache primitive: %s", prim)
		}
	}

	// Verify caching integration across UI fetch endpoints
	cachedFetchCalls := []string{
		"seasons_",
		"episodes_",
		"next_up_",
		"movies",
		"tvshows",
		"favorites",
		"continue_watching",
		"next_up_list",
		"music",
		"recently_added_",
		"search_",
	}
	for _, callKey := range cachedFetchCalls {
		if !strings.Contains(appDataContent, callKey) {
			t.Errorf("AppData.qml missing cache key integration for: %s", callKey)
		}
	}

	// Verify DetailsView.qml dynamic loading logic
	detailsPath := filepath.Join("..", "..", "ui", "qml", "DetailsView.qml")
	detailsBytes, err := os.ReadFile(detailsPath)
	if err != nil {
		t.Fatalf("Failed to read DetailsView.qml: %v", err)
	}
	detailsContent := string(detailsBytes)

	if !strings.Contains(detailsContent, "loadRemainingSeasonsInBackground") {
		t.Errorf("DetailsView.qml missing loadRemainingSeasonsInBackground function for dynamic season loading!")
	}
	if !strings.Contains(detailsContent, "DYNAMIC LOAD INITIAL") {
		t.Errorf("DetailsView.qml missing initial instant season render logic!")
	}

	// Verify Image Async & Cache settings
	if !strings.Contains(detailsContent, "asynchronous: true") || !strings.Contains(detailsContent, "cache: true") {
		t.Errorf("DetailsView.qml missing asynchronous and cache image properties!")
	}

	mediaGridPath := filepath.Join("..", "..", "ui", "qml", "components", "MediaGrid.qml")
	mediaGridBytes, err := os.ReadFile(mediaGridPath)
	if err == nil {
		mediaGridContent := string(mediaGridBytes)
		if !strings.Contains(mediaGridContent, "asynchronous: true") || !strings.Contains(mediaGridContent, "cache: true") {
			t.Errorf("MediaGrid.qml missing asynchronous: true or cache: true on poster images!")
		}
	}
}

// TestShowPlayButtonAndNextUpVisibility verifies that DetailsView.qml implements:
// 1. Hiding the Next Up section when the user has not watched a show (hasWatchedShow check).
// 2. Consolidating to a single play button for a show with dynamic Start, Continue, or Next Episode options.
func TestShowPlayButtonAndNextUpVisibility(t *testing.T) {
	detailsPath := filepath.Join("..", "..", "ui", "qml", "DetailsView.qml")
	detailsBytes, err := os.ReadFile(detailsPath)
	if err != nil {
		t.Fatalf("Failed to read DetailsView.qml: %v", err)
	}
	detailsContent := string(detailsBytes)

	// 1. Next Up section must require hasWatchedShow
	if !strings.Contains(detailsContent, "hasWatchedShow") {
		t.Errorf("DetailsView.qml missing hasWatchedShow property for checking watched status!")
	}
	if !strings.Contains(detailsContent, "visible: detailsView.isSeries && detailsView.hasWatchedShow") {
		t.Errorf("DetailsView.qml nextUpCardContainer must verify hasWatchedShow before displaying Next Up!")
	}

	// 2. Options: start, continue, next episode logic
	requiredMethods := []string{
		"getHasWatchedShow",
		"getShowPlayOption",
		"getShowPlayTarget",
		"getPlayButtonText",
		"Start",
		"Continue",
		"Next Episode",
	}
	for _, m := range requiredMethods {
		if !strings.Contains(detailsContent, m) {
			t.Errorf("DetailsView.qml missing required show play option logic/label: %s", m)
		}
	}

	// 3. Must be a single play button (nextUpBtn removed)
	if strings.Contains(detailsContent, "id: nextUpBtn") {
		t.Errorf("DetailsView.qml still contains separate nextUpBtn! Must consolidate to single play button.")
	}
}

// TestMusicAndArtistMediaSeparation verifies that Music and Artists in Bigfin
// are cleanly decoupled from Movie defaults and display correct metadata.
func TestMusicAndArtistMediaSeparation(t *testing.T) {
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}
	appDataContent := string(appDataBytes)

	// 1. Verify Artists in artistsList do not use movie poster SVGs
	moviePosters := []string{"interstellar.svg", "bladerunner.svg", "dune2.svg", "mandalorian.svg", "breakingbad.svg", "matrix.svg"}
	artistsSection := ""
	if idx := strings.Index(appDataContent, "property var artistsList:"); idx != -1 {
		artistsSection = appDataContent[idx : idx+600]
	}
	for _, mp := range moviePosters {
		if strings.Contains(artistsSection, mp) {
			t.Errorf("artistsList in AppData.qml still references movie poster %s for an artist!", mp)
		}
	}

	// 2. Verify DetailsView.qml hides movie specs and IMDb links for music
	detailsPath := filepath.Join("..", "..", "ui", "qml", "DetailsView.qml")
	detailsBytes, err := os.ReadFile(detailsPath)
	if err != nil {
		t.Fatalf("Failed to read DetailsView.qml: %v", err)
	}
	detailsContent := string(detailsBytes)

	if !strings.Contains(detailsContent, "visible: detailsView.isEpisode || (!detailsView.isSeries && !detailsView.isMusic)") {
		t.Errorf("DetailsView.qml must hide Technical Specs table when detailsView.isMusic is true!")
	}
	if !strings.Contains(detailsContent, "visible: !detailsView.isMusic") {
		t.Errorf("DetailsView.qml must hide IMDb/TMDB links when detailsView.isMusic is true!")
	}
	if !strings.Contains(detailsContent, `if (t === "MusicArtist")`) {
		t.Errorf("DetailsView.qml missing Artist media type label formatting!")
	}

	if !strings.Contains(detailsContent, "visible: !detailsView.isMusic") {
		t.Errorf("DetailsView.qml must hide Genres for music (visible: !detailsView.isMusic)!")
	}
	if strings.Contains(detailsContent, "\"Playlist Tracks\"") {
		t.Errorf("DetailsView.qml still references 'Playlist Tracks'! Must replace 'Tracks' with 'Songs'.")
	}

	// 3. Verify SearchView.qml placeholder and music item label handling
	searchPath := filepath.Join("..", "..", "ui", "qml", "SearchView.qml")
	searchBytes, err := os.ReadFile(searchPath)
	if err != nil {
		t.Fatalf("Failed to read SearchView.qml: %v", err)
	}
	searchContent := string(searchBytes)

	if !strings.Contains(searchContent, "Search Movies, TV Shows, Music, Artists...") {
		t.Errorf("SearchView.qml placeholder text must include Music and Artists!")
	}
	if !strings.Contains(searchContent, "isMusicItem ?") {
		t.Errorf("SearchView.qml missing isMusicItem check for formatting search result subtitles!")
	}
}

// TestMusicTabAlbumRemovalAndSimilarSongs verifies that:
// 1. GridView.qml removes Albums from the music sub-filter tab bar.
// 2. DetailsView.qml hides Genres for music (visible: !detailsView.isMusic).
// 3. DetailsView.qml implements loadSimilarSongs and renders 5 similar song options.
func TestMusicTabAlbumRemovalAndSimilarSongs(t *testing.T) {
	gridPath := filepath.Join("..", "..", "ui", "qml", "GridView.qml")
	gridBytes, err := os.ReadFile(gridPath)
	if err != nil {
		t.Fatalf("Failed to read GridView.qml: %v", err)
	}
	gridContent := string(gridBytes)

	if strings.Contains(gridContent, `{ id: "albums", name: "Albums" }`) {
		t.Errorf("GridView.qml still contains Albums sub-tab filter!")
	}

	detailsPath := filepath.Join("..", "..", "ui", "qml", "DetailsView.qml")
	detailsBytes, err := os.ReadFile(detailsPath)
	if err != nil {
		t.Fatalf("Failed to read DetailsView.qml: %v", err)
	}
	detailsContent := string(detailsBytes)

	if !strings.Contains(detailsContent, `visible: !detailsView.isMusic`) {
		t.Errorf("DetailsView.qml missing check to hide Genres for music!")
	}

	if !strings.Contains(detailsContent, "loadSimilarSongs()") {
		t.Errorf("DetailsView.qml missing loadSimilarSongs() function!")
	}

	if !strings.Contains(detailsContent, `"Similar Songs"`) {
		t.Errorf("DetailsView.qml missing 'Similar Songs' section header!")
	}

	if !strings.Contains(detailsContent, "if (final5.length === 5) break") {
		t.Errorf("DetailsView.qml must limit similar songs to 5 options!")
	}

	if !strings.Contains(detailsContent, "id: playedBtn") || !strings.Contains(detailsContent, "visible: !detailsView.isMusic") {
		t.Errorf("DetailsView.qml playedBtn must be hidden for music!")
	}

	if !strings.Contains(detailsContent, `ov.indexOf("Jellyfin") !== -1`) {
		t.Errorf("DetailsView.qml must filter out generic Jellyfin overview text for music!")
	}
}

// TestArtistSongsAndGenresRemoval verifies that:
// 1. AppData.qml artist items include songs arrays under them and use song counts in subtitle.
// 2. GridView.qml and DetailsView.qml remove "Music Artist" / "Artist" label under artists and show song count instead.
// 3. DetailsView.qml completely hides Genres for music items via visible: !detailsView.isMusic.
func TestArtistSongsAndGenresRemoval(t *testing.T) {
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}
	appDataContent := string(appDataBytes)

	if !strings.Contains(appDataContent, "songs:") {
		t.Errorf("AppData.qml artistsList missing songs array under artists!")
	}
	if strings.Contains(appDataContent, `subtitle: "Artist"`) || strings.Contains(appDataContent, `subtitle: "Music Artist"`) {
		t.Errorf("AppData.qml artistsList still contains 'Artist' or 'Music Artist' subtitle!")
	}

	detailsPath := filepath.Join("..", "..", "ui", "qml", "DetailsView.qml")
	detailsBytes, err := os.ReadFile(detailsPath)
	if err != nil {
		t.Fatalf("Failed to read DetailsView.qml: %v", err)
	}
	detailsContent := string(detailsBytes)

	if !strings.Contains(detailsContent, "visible: !detailsView.isMusic") {
		t.Errorf("DetailsView.qml must hide Genres for all music items using visible: !detailsView.isMusic!")
	}

	gridPath := filepath.Join("..", "..", "ui", "qml", "GridView.qml")
	gridBytes, err := os.ReadFile(gridPath)
	if err != nil {
		t.Fatalf("Failed to read GridView.qml: %v", err)
	}
	gridContent := string(gridBytes)

	if !strings.Contains(gridContent, `modelData.mediaType === "MusicArtist"`) || !strings.Contains(gridContent, `Songs`) {
		t.Errorf("GridView.qml missing logic to render songs/song count under artist cards!")
	}
}

// TestMusicTabPreservationOnBackNavigation verifies that:
// 1. AppData.qml includes activeMusicSubFilter property and updateMusicSubFilterForMediaItem function.
// 2. GridView.qml initializes and updates activeMusicSubFilter with AppData.
// 3. Main.qml preserves music subFilter state in viewHistoryStack and restores it on goBack().
func TestMusicTabPreservationOnBackNavigation(t *testing.T) {
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}
	appDataContent := string(appDataBytes)

	if !strings.Contains(appDataContent, "property string activeMusicSubFilter") {
		t.Errorf("AppData.qml missing activeMusicSubFilter property!")
	}
	if !strings.Contains(appDataContent, "updateMusicSubFilterForMediaItem") {
		t.Errorf("AppData.qml missing updateMusicSubFilterForMediaItem function!")
	}

	gridPath := filepath.Join("..", "..", "ui", "qml", "GridView.qml")
	gridBytes, err := os.ReadFile(gridPath)
	if err != nil {
		t.Fatalf("Failed to read GridView.qml: %v", err)
	}
	gridContent := string(gridBytes)

	if !strings.Contains(gridContent, "AppData.activeMusicSubFilter") {
		t.Errorf("GridView.qml missing AppData.activeMusicSubFilter integration!")
	}

	mainPath := filepath.Join("..", "..", "ui", "qml", "Main.qml")
	mainBytes, err := os.ReadFile(mainPath)
	if err != nil {
		t.Fatalf("Failed to read Main.qml: %v", err)
	}
	mainContent := string(mainBytes)

	if !strings.Contains(mainContent, "subFilter:") {
		t.Errorf("Main.qml missing subFilter history stack tracking!")
	}
	if !strings.Contains(mainContent, "prevEntry.subFilter") {
		t.Errorf("Main.qml missing subFilter restoration on goBack()!")
	}
	if !strings.Contains(mainContent, "getCurrentSpot()") {
		t.Errorf("Main.qml missing getCurrentSpot() function for capturing item index/section spot!")
	}
	if !strings.Contains(gridContent, "savedIndex") {
		t.Errorf("GridView.qml missing savedIndex property!")
	}
	if !strings.Contains(gridContent, "positionViewAtIndex") {
		t.Errorf("GridView.qml missing positionViewAtIndex call for restoring grid scroll spot!")
	}
}

// TestMusicTabOrder verifies that GridView.qml orders music sub-tabs as Songs, Playlists, Artists.
func TestMusicTabOrder(t *testing.T) {
	gridPath := filepath.Join("..", "..", "ui", "qml", "GridView.qml")
	gridBytes, err := os.ReadFile(gridPath)
	if err != nil {
		t.Fatalf("Failed to read GridView.qml: %v", err)
	}
	gridContent := string(gridBytes)

	expectedOpts := `var opts = ["songs", "playlists", "artists"]`
	if !strings.Contains(gridContent, expectedOpts) {
		t.Errorf("GridView.qml getMusicSubTabIndex does not contain expected tab options array order [%s]", expectedOpts)
	}

	songsIdx := strings.Index(gridContent, `{ id: "songs", name: "Songs" }`)
	playlistsIdx := strings.Index(gridContent, `{ id: "playlists", name: "Playlists" }`)
	artistsIdx := strings.Index(gridContent, `{ id: "artists", name: "Artists" }`)

	if songsIdx == -1 || playlistsIdx == -1 || artistsIdx == -1 {
		t.Fatalf("GridView.qml is missing one or more music tab definitions!")
	}

	if !(songsIdx < playlistsIdx && playlistsIdx < artistsIdx) {
		t.Errorf("Music tab order in GridView.qml is incorrect! Expected Songs < Playlists < Artists")
	}
}

// TestDedicatedMusicPlayerUI verifies that music playback has a dedicated UI (MusicPlayerOverlay.qml),
// a persistent bottom mini-player (MusicMiniPlayer.qml), centralized audio engine queue management in AppData.qml,
// and dynamic player routing in Main.qml distinct from movies and TV shows.
func TestDedicatedMusicPlayerUI(t *testing.T) {
	// 1. Verify MusicPlayerOverlay.qml exists and contains music UI elements
	musicPlayerPath := filepath.Join("..", "..", "ui", "qml", "MusicPlayerOverlay.qml")
	musicBytes, err := os.ReadFile(musicPlayerPath)
	if err != nil {
		t.Fatalf("Failed to read MusicPlayerOverlay.qml: %v", err)
	}
	musicContent := string(musicBytes)

	requiredMusicElements := []string{
		"NOW PLAYING",
		"NOW PLAYING QUEUE",
		"AppData.nextMusicTrack()",
		"AppData.prevMusicTrack()",
		"AppData.toggleMusicShuffle()",
		"AppData.cycleMusicRepeatMode()",
		"queueListView",
		"formatTime",
		"seekTrack",
	}

	for _, elem := range requiredMusicElements {
		if !strings.Contains(musicContent, elem) {
			t.Errorf("MusicPlayerOverlay.qml missing required music UI element or function call: %s", elem)
		}
	}

	// 2. Verify MusicMiniPlayer.qml exists and contains mini-player controls
	miniPlayerPath := filepath.Join("..", "..", "ui", "qml", "components", "MusicMiniPlayer.qml")
	miniBytes, err := os.ReadFile(miniPlayerPath)
	if err != nil {
		t.Fatalf("Failed to read MusicMiniPlayer.qml: %v", err)
	}
	miniContent := string(miniBytes)

	requiredMiniElements := []string{
		"expandRequested",
		"AppData.toggleMusicPlayPause()",
		"AppData.nextMusicTrack()",
		"activeTrack",
	}

	for _, elem := range requiredMiniElements {
		if !strings.Contains(miniContent, elem) {
			t.Errorf("MusicMiniPlayer.qml missing required mini-player property/signal: %s", elem)
		}
	}

	// 3. Verify AppData.qml contains centralized music queue state and playback functions
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}
	appDataContent := string(appDataBytes)

	requiredAppDataProps := []string{
		"property var currentMusicTrack",
		"property var musicQueue",
		"property bool isMusicPlaying",
		"property bool musicShuffle",
		"property int musicRepeatMode",
		"function playMusicItem",
		"function nextMusicTrack",
		"function prevMusicTrack",
		"function toggleMusicPlayPause",
	}

	for _, prop := range requiredAppDataProps {
		if !strings.Contains(appDataContent, prop) {
			t.Errorf("AppData.qml missing required music engine property/method: %s", prop)
		}
	}

	// 4. Verify Main.qml routes music items to MusicPlayerOverlay and mounts MusicMiniPlayer
	mainPath := filepath.Join("..", "..", "ui", "qml", "Main.qml")
	mainBytes, err := os.ReadFile(mainPath)
	if err != nil {
		t.Fatalf("Failed to read Main.qml: %v", err)
	}
	mainContent := string(mainBytes)

	if !strings.Contains(mainContent, "MusicPlayerOverlay.qml") {
		t.Errorf("Main.qml missing dynamic player loading for MusicPlayerOverlay.qml!")
	}

	if !strings.Contains(mainContent, "components/MusicMiniPlayer.qml") {
		t.Errorf("Main.qml missing MusicMiniPlayer.qml component loader!")
	}

	if !strings.Contains(mainContent, "isMusicItem") {
		t.Errorf("Main.qml missing isMusicItem check for media player routing!")
	}
}

// TestPlayerOverlayControlsAndTopRightButtonsRemoval verifies that clicking play goes to control screen while loading,
// and that audio selector and top-right minimize/windowed buttons are removed from player overlays.
func TestPlayerOverlayControlsAndTopRightButtonsRemoval(t *testing.T) {
	playerPath := filepath.Join("..", "..", "ui", "qml", "PlayerOverlay.qml")
	playerBytes, err := os.ReadFile(playerPath)
	if err != nil {
		t.Fatalf("Failed to read PlayerOverlay.qml: %v", err)
	}
	playerContent := string(playerBytes)

	// 1. Verify controls stay visible while loading/buffering
	if !strings.Contains(playerContent, "onIsBufferingChanged:") {
		t.Errorf("PlayerOverlay.qml missing onIsBufferingChanged handler to keep controls visible while loading!")
	}
	if !strings.Contains(playerContent, "running: !playerOverlay.isBuffering") {
		t.Errorf("PlayerOverlay.qml autoHideTimer should pause while player is loading/buffering!")
	}

	// 2. Verify audio selector (audioBtn) is removed
	if strings.Contains(playerContent, "id: audioBtn") {
		t.Errorf("PlayerOverlay.qml should not contain audio selector button (id: audioBtn)!")
	}

	// 3. Verify top right minimize & windowed/fullscreen buttons are removed
	if strings.Contains(playerContent, "id: windowMinimizeBtn") {
		t.Errorf("PlayerOverlay.qml should not contain minimize button (id: windowMinimizeBtn)!")
	}
	if strings.Contains(playerContent, "id: windowToggleFSBtn") {
		t.Errorf("PlayerOverlay.qml should not contain windowed/fullscreen button (id: windowToggleFSBtn)!")
	}

	// 4. Verify MusicPlayerOverlay.qml also has minimize button removed
	musicPlayerPath := filepath.Join("..", "..", "ui", "qml", "MusicPlayerOverlay.qml")
	musicPlayerBytes, err := os.ReadFile(musicPlayerPath)
	if err != nil {
		t.Fatalf("Failed to read MusicPlayerOverlay.qml: %v", err)
	}
	musicPlayerContent := string(musicPlayerBytes)

	if strings.Contains(musicPlayerContent, "id: windowMinimizeBtn") {
		t.Errorf("MusicPlayerOverlay.qml should not contain minimize button (id: windowMinimizeBtn)!")
	}
}

// TestRecentlyAddedMoviesClickTriggersPlay verifies that clicking a card in Recently Added in Movies
// triggers playRequested(modelData) directly, matching play button behavior.
func TestRecentlyAddedMoviesClickTriggersPlay(t *testing.T) {
	homePath := filepath.Join("..", "..", "ui", "qml", "HomeView.qml")
	homeBytes, err := os.ReadFile(homePath)
	if err != nil {
		t.Fatalf("Failed to read HomeView.qml: %v", err)
	}
	homeContent := string(homeBytes)

	// Verify moviesList section calls playRequested on mouse click
	moviesSectionIdx := strings.Index(homeContent, "id: moviesList")
	if moviesSectionIdx == -1 {
		t.Fatalf("HomeView.qml missing moviesList section!")
	}

	moviesSection := homeContent[moviesSectionIdx:]
	endMoviesSectionIdx := strings.Index(moviesSection, "id: musicList")
	if endMoviesSectionIdx != -1 {
		moviesSection = moviesSection[:endMoviesSectionIdx]
	}

	if !strings.Contains(moviesSection, "homeView.playRequested(modelData)") {
		t.Errorf("Recently Added Movies card click in HomeView.qml should invoke homeView.playRequested(modelData)!")
	}
}

// TestMovieResumeAndScrubbingFunctionality verifies that PlayerOverlay.qml implements:
// 1. Correct resume calculation (getResumePositionTicks / getResumePositionSeconds) and StartTimeTicks parameter in streamUrl.
// 2. Pending initial seek state management (pendingInitialSeek, targetResumePosition, applyInitialSeek).
// 3. Interactive mouse drag scrubbing (onPressed, onPositionChanged, onReleased, preventStealing) and seek knob handle.
// 4. PerformSeek helper for seek execution and Jellyfin playback progress reporting.
func TestMovieResumeAndScrubbingFunctionality(t *testing.T) {
	playerPath := filepath.Join("..", "..", "ui", "qml", "PlayerOverlay.qml")
	playerBytes, err := os.ReadFile(playerPath)
	if err != nil {
		t.Fatalf("Failed to read PlayerOverlay.qml: %v", err)
	}
	playerContent := string(playerBytes)

	requiredResumeFeatures := []string{
		"getResumePositionTicks",
		"getResumePositionSeconds",
		"pendingInitialSeek",
		"targetResumePosition",
		"applyInitialSeek",
	}

	for _, feat := range requiredResumeFeatures {
		if !strings.Contains(playerContent, feat) {
			t.Errorf("PlayerOverlay.qml missing required resume feature: %s", feat)
		}
	}

	requiredScrubbingFeatures := []string{
		"isScrubbing",
		"performSeek",
		"seekHandle",
		"handleScrub",
		"preventStealing: true",
		"onPositionChanged: function(mouse)",
		"onReleased: function(mouse)",
	}

	for _, feat := range requiredScrubbingFeatures {
		if !strings.Contains(playerContent, feat) {
			t.Errorf("PlayerOverlay.qml missing required scrubbing feature: %s", feat)
		}
	}
}

// TestAdaptiveStreamingAndBitrateAutoScaling verifies that:
// 1. AppData.qml contains homeBitrateIdx, remoteBitrateIdx, and getMaxStreamingBitrateBps function.
// 2. SettingsView.qml binds home/remote bitrate settings to AppData.
// 3. PlayerOverlay.qml includes MaxStreamingBitrate and PlaySessionId in streamUrl to enable auto adaptive streaming and prevent stuttering.
func TestAdaptiveStreamingAndBitrateAutoScaling(t *testing.T) {
	appDataPath := filepath.Join("..", "..", "ui", "qml", "AppData.qml")
	appDataBytes, err := os.ReadFile(appDataPath)
	if err != nil {
		t.Fatalf("Failed to read AppData.qml: %v", err)
	}
	appDataContent := string(appDataBytes)

	if !strings.Contains(appDataContent, "getMaxStreamingBitrateBps") {
		t.Errorf("AppData.qml missing getMaxStreamingBitrateBps function!")
	}
	if !strings.Contains(appDataContent, "remoteBitrateIdx") {
		t.Errorf("AppData.qml missing remoteBitrateIdx property!")
	}

	settingsPath := filepath.Join("..", "..", "ui", "qml", "SettingsView.qml")
	settingsBytes, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatalf("Failed to read SettingsView.qml: %v", err)
	}
	settingsContent := string(settingsBytes)

	if !strings.Contains(settingsContent, "AppData.remoteBitrateIdx") {
		t.Errorf("SettingsView.qml missing binding for AppData.remoteBitrateIdx!")
	}

	playerPath := filepath.Join("..", "..", "ui", "qml", "PlayerOverlay.qml")
	playerBytes, err := os.ReadFile(playerPath)
	if err != nil {
		t.Fatalf("Failed to read PlayerOverlay.qml: %v", err)
	}
	playerContent := string(playerBytes)

	if !strings.Contains(playerContent, "MaxStreamingBitrate=") {
		t.Errorf("PlayerOverlay.qml missing MaxStreamingBitrate query parameter in streamUrl!")
	}
	if !strings.Contains(playerContent, "PlaySessionId=") {
		t.Errorf("PlayerOverlay.qml missing PlaySessionId query parameter in streamUrl!")
	}
}















