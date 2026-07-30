package jellyfin

import "bytes"
import "context"
import "encoding/json"
import "fmt"
import "io"
import "net/http"
import "net/url"
import "sync"
import "time"

const (
	ClientName    = "Bigfin"
	DeviceName    = "Plasma Bigscreen TV"
	DeviceID      = "bigfin-plasma-tv-01"
	ClientVersion = "0.1.0"
)

// Client handles communication with the Jellyfin REST API and image caching
type Client struct {
	ServerURL   string
	AccessToken string
	UserID      string
	httpClient  *http.Client
	imgCache    map[string][]byte
	cacheMu     sync.RWMutex
}

// NewClient initializes a Jellyfin API Client instance
func NewClient(serverURL string) *Client {
	return &Client{
		ServerURL:  serverURL,
		httpClient: &http.Client{Timeout: 15 * time.Second},
		imgCache:   make(map[string][]byte),
	}
}

// setAuthHeaders sets the mandatory X-Emby-Authorization header on requests
func (c *Client) setAuthHeaders(req *http.Request) {
	headerVal := fmt.Sprintf(
		`MediaBrowser Client="%s", Device="%s", DeviceId="%s", Version="%s"`,
		ClientName, DeviceName, DeviceID, ClientVersion,
	)
	if c.AccessToken != "" {
		headerVal += fmt.Sprintf(`, Token="%s"`, c.AccessToken)
	}
	req.Header.Set("X-Emby-Authorization", headerVal)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
}

// Do execute HTTP request with authentication headers
func (c *Client) Do(ctx context.Context, method, endpoint string, body io.Reader) (*http.Response, error) {
	fullURL := fmt.Sprintf("%s%s", c.ServerURL, endpoint)
	req, err := http.NewRequestWithContext(ctx, method, fullURL, body)
	if err != nil {
		return nil, fmt.Errorf("failed to create request: %w", err)
	}

	c.setAuthHeaders(req)
	resp, err := c.httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("HTTP request failed: %w", err)
	}
	return resp, nil
}

// FetchUserViews returns the top-level user libraries (Movies, TV Shows, Music, etc.)
func (c *Client) FetchUserViews(ctx context.Context) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}

	endpoint := fmt.Sprintf("/Users/%s/Views", c.UserID)
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode views JSON: %w", err)
	}
	return result.Items, nil
}

// FetchItems retrieves items inside a library or container with optional query filters
func (c *Client) FetchItems(ctx context.Context, parentID string, includeTypes string, limit int) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}

	params := url.Values{}
	if parentID != "" {
		params.Set("ParentId", parentID)
	}
	if includeTypes != "" {
		params.Set("IncludeItemTypes", includeTypes)
	}
	if limit > 0 {
		params.Set("Limit", fmt.Sprintf("%d", limit))
	}
	params.Set("Fields", "PrimaryImageAspectRatio,Overview,Genres,MediaSources,UserData")

	endpoint := fmt.Sprintf("/Users/%s/Items?%s", c.UserID, params.Encode())
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode items JSON: %w", err)
	}
	return result.Items, nil
}

// BuildImageURL constructs a Jellyfin image URL for a given item and image type
func (c *Client) BuildImageURL(itemID, imageType string, width, height int) string {
	baseURL := fmt.Sprintf("%s/Items/%s/Images/%s", c.ServerURL, itemID, imageType)
	params := url.Values{}
	if width > 0 {
		params.Set("fillWidth", fmt.Sprintf("%d", width))
	}
	if height > 0 {
		params.Set("fillHeight", fmt.Sprintf("%d", height))
	}
	params.Set("quality", "90")
	if len(params) > 0 {
		return fmt.Sprintf("%s?%s", baseURL, params.Encode())
	}
	return baseURL
}

// FetchImageAsync fetches an image thumbnail concurrently using goroutines and caches it
func (c *Client) FetchImageAsync(ctx context.Context, imageURL string, callback func(data []byte, err error)) {
	c.cacheMu.RLock()
	if data, found := c.imgCache[imageURL]; found {
		c.cacheMu.RUnlock()
		callback(data, nil)
		return
	}
	c.cacheMu.RUnlock()

	go func() {
		req, err := http.NewRequestWithContext(ctx, http.MethodGet, imageURL, nil)
		if err != nil {
			callback(nil, err)
			return
		}
		resp, err := c.httpClient.Do(req)
		if err != nil {
			callback(nil, err)
			return
		}
		defer resp.Body.Close()

		if resp.StatusCode != http.StatusOK {
			callback(nil, fmt.Errorf("image fetch failed with status %d", resp.StatusCode))
			return
		}

		data, err := io.ReadAll(resp.Body)
		if err != nil {
			callback(nil, err)
			return
		}

		c.cacheMu.Lock()
		c.imgCache[imageURL] = data
		c.cacheMu.Unlock()

		callback(data, nil)
	}()
}

// ConstructStreamURL generates a direct stream URL for libmpv video or audio playback
func (c *Client) ConstructStreamURL(itemID, mediaSourceID, itemType string) string {
	params := url.Values{}
	params.Set("Static", "true")
	params.Set("MediaSourceId", mediaSourceID)
	if c.AccessToken != "" {
		params.Set("api_key", c.AccessToken)
	}

	endpointType := "Videos"
	if itemType == "Audio" || itemType == "MusicTrack" {
		endpointType = "Audio"
	}
	return fmt.Sprintf("%s/%s/%s/stream?%s", c.ServerURL, endpointType, itemID, params.Encode())
}

// ConstructAdaptiveHLSURL creates an HLS master playlist URL that automatically adapts resolution based on stream capabilities and bandwidth
func (c *Client) ConstructAdaptiveHLSURL(itemID, mediaSourceID string, maxHeight int) string {
	params := url.Values{}
	params.Set("MediaSourceId", mediaSourceID)
	params.Set("VideoCodec", "h264,hevc,av1")
	params.Set("AudioCodec", "aac,mp3,ac3,eac3")
	if maxHeight > 0 {
		params.Set("MaxHeight", fmt.Sprintf("%d", maxHeight))
	}
	if c.AccessToken != "" {
		params.Set("api_key", c.AccessToken)
	}
	return fmt.Sprintf("%s/Videos/%s/master.m3u8?%s", c.ServerURL, itemID, params.Encode())
}

// FetchNextUp retrieves TV episodes in the user's Next Up queue
func (c *Client) FetchNextUp(ctx context.Context, limit int) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}
	params := url.Values{}
	params.Set("UserId", c.UserID)
	if limit > 0 {
		params.Set("Limit", fmt.Sprintf("%d", limit))
	}
	params.Set("Fields", "PrimaryImageAspectRatio,Overview,MediaSources,UserData")

	endpoint := fmt.Sprintf("/Shows/NextUp?%s", params.Encode())
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode NextUp JSON: %w", err)
	}
	return result.Items, nil
}

// FetchResumeItems retrieves in-progress media items for Continue Watching
func (c *Client) FetchResumeItems(ctx context.Context, limit int) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}
	params := url.Values{}
	if limit > 0 {
		params.Set("Limit", fmt.Sprintf("%d", limit))
	}
	params.Set("Fields", "PrimaryImageAspectRatio,Overview,MediaSources,UserData")

	endpoint := fmt.Sprintf("/Users/%s/Items/Resume?%s", c.UserID, params.Encode())
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode Resume items JSON: %w", err)
	}
	return result.Items, nil
}

// FetchSeasons retrieves seasons for a given TV series
func (c *Client) FetchSeasons(ctx context.Context, seriesID string) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}
	endpoint := fmt.Sprintf("/Shows/%s/Seasons?UserId=%s&Fields=PrimaryImageAspectRatio,Overview,UserData", seriesID, c.UserID)
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode Seasons JSON: %w", err)
	}
	return result.Items, nil
}

// FetchEpisodes retrieves episodes for a given TV series & season
func (c *Client) FetchEpisodes(ctx context.Context, seriesID, seasonID string) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}
	params := url.Values{}
	params.Set("UserId", c.UserID)
	if seasonID != "" {
		params.Set("SeasonId", seasonID)
	}
	params.Set("Fields", "PrimaryImageAspectRatio,Overview,MediaSources,UserData")

	endpoint := fmt.Sprintf("/Shows/%s/Episodes?%s", seriesID, params.Encode())
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode Episodes JSON: %w", err)
	}
	return result.Items, nil
}

// SearchItems performs a search across media items
func (c *Client) SearchItems(ctx context.Context, query string, limit int) ([]BaseItem, error) {
	if c.UserID == "" {
		return nil, fmt.Errorf("user not authenticated")
	}
	params := url.Values{}
	params.Set("SearchTerm", query)
	params.Set("IncludeItemTypes", "Movie,Series,Episode,Audio")
	if limit > 0 {
		params.Set("Limit", fmt.Sprintf("%d", limit))
	}
	params.Set("Fields", "PrimaryImageAspectRatio,Overview,Genres,MediaSources,UserData")

	endpoint := fmt.Sprintf("/Users/%s/Items?%s", c.UserID, params.Encode())
	resp, err := c.Do(ctx, http.MethodGet, endpoint, nil)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("server returned status code: %d", resp.StatusCode)
	}

	var result ItemsQueryResult
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, fmt.Errorf("failed to decode search JSON: %w", err)
	}
	return result.Items, nil
}

// ReportPlaybackStart notifies Jellyfin that playback has started
func (c *Client) ReportPlaybackStart(ctx context.Context, report PlaybackProgressReport) error {
	payload, err := json.Marshal(report)
	if err != nil {
		return err
	}
	resp, err := c.Do(ctx, http.MethodPost, "/Sessions/Playing", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// ReportPlaybackProgress reports current playback position to Jellyfin
func (c *Client) ReportPlaybackProgress(ctx context.Context, report PlaybackProgressReport) error {
	payload, err := json.Marshal(report)
	if err != nil {
		return err
	}
	resp, err := c.Do(ctx, http.MethodPost, "/Sessions/Playing/Progress", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// ReportPlaybackStopped notifies Jellyfin that playback stopped
func (c *Client) ReportPlaybackStopped(ctx context.Context, report PlaybackProgressReport) error {
	payload, err := json.Marshal(report)
	if err != nil {
		return err
	}
	resp, err := c.Do(ctx, http.MethodPost, "/Sessions/Playing/Stopped", bytes.NewReader(payload))
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

// SetFavorite toggles favorite status of an item
func (c *Client) SetFavorite(ctx context.Context, itemID string, favorite bool) error {
	if c.UserID == "" {
		return fmt.Errorf("user not authenticated")
	}
	method := http.MethodPost
	if !favorite {
		method = http.MethodDelete
	}
	endpoint := fmt.Sprintf("/Users/%s/FavoriteItems/%s", c.UserID, itemID)
	resp, err := c.Do(ctx, method, endpoint, nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	return nil
}

