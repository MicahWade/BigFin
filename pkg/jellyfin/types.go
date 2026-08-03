package jellyfin

import "time"

// User holds user info returned from Jellyfin auth
type User struct {
	ID   string `json:"Id"`
	Name string `json:"Name"`
}

// AuthenticationResult represents the response from authenticating by name
type AuthenticationResult struct {
	User        User   `json:"User"`
	AccessToken string `json:"AccessToken"`
	ServerID    string `json:"ServerId"`
}

// SystemInfo represents server information
type SystemInfo struct {
	ServerName string `json:"ServerName"`
	Version    string `json:"Version"`
	ID         string `json:"Id"`
}

// BaseItem represents a Jellyfin media item (movie, series, episode, folder)
type BaseItem struct {
	ID                   string        `json:"Id"`
	Name                 string        `json:"Name"`
	OriginalTitle        string        `json:"OriginalTitle,omitempty"`
	ServerID             string        `json:"ServerId,omitempty"`
	Type                 string        `json:"Type"` // Movie, Series, Episode, Folder, CollectionFolder
	Overview             string        `json:"Overview,omitempty"`
	Taglines             []string      `json:"Taglines,omitempty"`
	Genres               []string      `json:"Genres,omitempty"`
	CommunityRating      float64       `json:"CommunityRating,omitempty"`
	OfficialRating       string        `json:"OfficialRating,omitempty"`
	RunTimeTicks         int64         `json:"RunTimeTicks,omitempty"`
	ProductionYear       int           `json:"ProductionYear,omitempty"`
	IsFolder             bool          `json:"IsFolder"`
	ImageTags            ImageTags     `json:"ImageTags,omitempty"`
	BackdropImageTags    []string      `json:"BackdropImageTags,omitempty"`
	UserData             UserData      `json:"UserData,omitempty"`
	MediaSources         []MediaSource `json:"MediaSources,omitempty"`
	SeriesName           string        `json:"SeriesName,omitempty"`
	SeriesID             string        `json:"SeriesId,omitempty"`
	SeasonName           string        `json:"SeasonName,omitempty"`
	SeasonID             string        `json:"SeasonId,omitempty"`
	IndexNumber          int           `json:"IndexNumber,omitempty"`
	ParentIndexNumber    int           `json:"ParentIndexNumber,omitempty"`
	ChildCount           int           `json:"ChildCount,omitempty"`
	RecursiveItemCount   int           `json:"RecursiveItemCount,omitempty"`
}

// ImageTags map for Primary, Logo, Thumb, etc.
type ImageTags struct {
	Primary string `json:"Primary,omitempty"`
	Banner  string `json:"Banner,omitempty"`
	Logo    string `json:"Logo,omitempty"`
	Thumb   string `json:"Thumb,omitempty"`
}

// UserData holds item playback and watch state
type UserData struct {
	PlaybackPositionTicks int64   `json:"PlaybackPositionTicks"`
	PlayCount             int     `json:"PlayCount"`
	IsFavorite            bool    `json:"IsFavorite"`
	Played                bool    `json:"Played"`
	PlayedPercentage      float64 `json:"PlayedPercentage,omitempty"`
}

// MediaSource describes stream sources for Direct Play evaluation
type MediaSource struct {
	ID                  string        `json:"Id"`
	Path                string        `json:"Path"`
	Protocol            string        `json:"Protocol"` // File, Http
	Container           string        `json:"Container"`
	Size                int64         `json:"Size"`
	SupportsDirectPlay  bool          `json:"SupportsDirectPlay"`
	SupportsDirectStream bool         `json:"SupportsDirectStream"`
	SupportsTranscoding  bool         `json:"SupportsTranscoding"`
	MediaStreams        []MediaStream `json:"MediaStreams"`
}

// MediaStream describes video/audio/subtitle streams inside a MediaSource
type MediaStream struct {
	Codec                  string `json:"Codec"`
	Language               string `json:"Language,omitempty"`
	DisplayTitle           string `json:"DisplayTitle,omitempty"`
	Type                   string `json:"Type"` // Audio, Video, Subtitle
	Index                  int    `json:"Index"`
	IsDefault              bool   `json:"IsDefault"`
	IsForced               bool   `json:"IsForced"`
	Width                  int    `json:"Width,omitempty"`
	Height                 int    `json:"Height,omitempty"`
	BitRate                int    `json:"BitRate,omitempty"`
	Channels               int    `json:"Channels,omitempty"`
	SampleRate             int    `json:"SampleRate,omitempty"`
}

// ItemsQueryResult represents paged query response from Jellyfin
type ItemsQueryResult struct {
	Items            []BaseItem `json:"Items"`
	TotalRecordCount int        `json:"TotalRecordCount"`
	StartIndex       int        `json:"StartIndex"`
}

// AuthRequest represents credentials sent to /Users/AuthenticateByName
type AuthRequest struct {
	Username string `json:"Username"`
	Pw       string `json:"Pw"`
}

// PlaybackProgressReport for reporting state back to Jellyfin
type PlaybackProgressReport struct {
	ItemID        string `json:"ItemId"`
	MediaSourceID string `json:"MediaSourceId"`
	PositionTicks int64  `json:"PositionTicks"`
	IsPaused      bool   `json:"IsPaused"`
	EventName     string `json:"EventName"` // timeupdate, pause, unpause, stop
}

// Session represents a stored login session for a Jellyfin server
type Session struct {
	ID            string    `json:"id"`
	ServerURL     string    `json:"serverUrl"`
	ServerName    string    `json:"serverName"`
	ServerVersion string    `json:"serverVersion"`
	UserID        string    `json:"userId"`
	Username      string    `json:"username"`
	AccessToken   string    `json:"accessToken"`
	DeviceID      string    `json:"deviceId"`
	LastUsed      time.Time `json:"lastUsed"`
}

// SessionStore represents persistent session configuration storage file
type SessionStore struct {
	ActiveSessionID string    `json:"activeSessionId"`
	Sessions        []Session `json:"sessions"`
}

// CacheEntry represents an cached image or item in memory/disk
type CacheEntry struct {
	URL       string
	Data      []byte
	FetchedAt time.Time
}

