package jellyfin

import "bytes"
import "context"
import "encoding/json"
import "fmt"
import "net/http"

// AuthenticateByName authenticates a user against the Jellyfin server
func (c *Client) AuthenticateByName(ctx context.Context, username, password string) (*AuthenticationResult, error) {
	authReq := AuthRequest{
		Username: username,
		Pw:       password,
	}

	payload, err := json.Marshal(authReq)
	if err != nil {
		return nil, fmt.Errorf("failed to marshal auth request: %w", err)
	}

	resp, err := c.Do(ctx, http.MethodPost, "/Users/AuthenticateByName", bytes.NewReader(payload))
	if err != nil {
		return nil, fmt.Errorf("auth request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("authentication failed with status code %d", resp.StatusCode)
	}

	var authResult AuthenticationResult
	if err := json.NewDecoder(resp.Body).Decode(&authResult); err != nil {
		return nil, fmt.Errorf("failed to parse auth response: %w", err)
	}

	c.AccessToken = authResult.AccessToken
	c.UserID = authResult.User.ID

	return &authResult, nil
}

// GetSystemInfo retrieves public server information to verify connectivity
func (c *Client) GetSystemInfo(ctx context.Context) (*SystemInfo, error) {
	resp, err := c.Do(ctx, http.MethodGet, "/System/Info/Public", nil)
	if err != nil {
		return nil, fmt.Errorf("system info request failed: %w", err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("failed to fetch system info, status %d", resp.StatusCode)
	}

	var info SystemInfo
	if err := json.NewDecoder(resp.Body).Decode(&info); err != nil {
		return nil, fmt.Errorf("failed to parse system info JSON: %w", err)
	}

	return &info, nil
}
