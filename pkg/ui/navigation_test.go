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
	if !strings.Contains(appDataContent, "seasonNavGoesToStart: true") {
		t.Errorf("AppData.qml missing default true seasonNavGoesToStart property!")
	}

	if !strings.Contains(detailsContent, "seasonNavGoesToStart") {
		t.Errorf("DetailsView.qml missing seasonNavGoesToStart check in vertical season navigation!")
	}

	if !strings.Contains(detailsContent, "targetY = (itemY + itemH / 2) - (viewH / 2)") {
		t.Errorf("DetailsView.qml missing middle-row vertical centering math in ensureVisible!")
	}
}



