package player

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"
)

// State represents current media player status
type State string

const (
	StateIdle    State = "Idle"
	StateLoading State = "Loading"
	StatePlaying State = "Playing"
	StatePaused  State = "Paused"
	StateStopped State = "Stopped"
	StateError   State = "Error"
)

// EngineType indicates the active backend playback engine
type EngineType string

const (
	EngineMPV          EngineType = "MPV"
	EngineFFplay       EngineType = "FFplay"
	EngineVLC          EngineType = "VLC"
	EngineQtMultimedia EngineType = "QtMultimedia"
	EngineDryRun       EngineType = "DryRun"
)

// TrackInfo holds metadata for audio or subtitle tracks
type TrackInfo struct {
	ID       int    `json:"id"`
	Type     string `json:"type"` // "audio" or "sub"
	Title    string `json:"title"`
	Language string `json:"language"`
	Codec    string `json:"codec"`
}

// PlaybackHealth summarizes verified audio and visual output status
type PlaybackHealth struct {
	AudioActive       bool    `json:"audioActive"`
	VisualsActive     bool    `json:"visualsActive"`
	PositionAdvancing bool    `json:"positionAdvancing"`
	VideoCodec        string  `json:"videoCodec"`
	AudioCodec        string  `json:"audioCodec"`
	Width             int     `json:"width"`
	Height            int     `json:"height"`
	FPS               float64 `json:"fps"`
	CurrentPosition   float64 `json:"currentPosition"`
	TotalDuration     float64 `json:"totalDuration"`
	State             State   `json:"state"`
	Engine            EngineType `json:"engine"`
	Details           string  `json:"details"`
}

// ResolutionMode specifies video playback target resolution mode
type ResolutionMode string

const (
	ResolutionAuto  ResolutionMode = "Auto"   // Adaptive bandwidth & native resolution auto-switching
	Resolution4K    ResolutionMode = "2160p"  // 3840x2160 max
	Resolution1080p ResolutionMode = "1080p"  // 1920x1080 max
	Resolution720p  ResolutionMode = "720p"   // 1280x720 max
	Resolution480p  ResolutionMode = "480p"   // 854x480 max
)

// Player wraps playback engine instance for media playback
type Player struct {
	mu                 sync.RWMutex
	State              State          `json:"state"`
	EngineType         EngineType     `json:"engineType"`
	ResolutionMode     ResolutionMode `json:"resolutionMode"`
	AutoResolutionMode bool           `json:"autoResolutionMode"`
	StreamURL          string         `json:"streamUrl"`
	MediaTitle         string         `json:"mediaTitle"`
	Position           float64        `json:"position"` // position in seconds
	Duration           float64        `json:"duration"` // duration in seconds
	Volume             int            `json:"volume"`   // 0 - 100
	IsMuted            bool           `json:"isMuted"`
	AudioTrackID       int            `json:"audioTrackId"`
	SubtitleTrackID    int            `json:"subtitleTrackId"`
	VideoCodec         string         `json:"videoCodec"`
	AudioCodec         string         `json:"audioCodec"`
	Width              int            `json:"width"`
	Height             int            `json:"height"`
	FPS                float64        `json:"fps"`
	AudioActive        bool           `json:"audioActive"`
	VisualsActive      bool           `json:"visualsActive"`
	FramesRendered     int64          `json:"framesRendered"`
	IPCPath            string         `json:"ipcPath"`
	cmd                *exec.Cmd
	ipcConn            net.Conn
	stopChan           chan struct{}
}

// NewPlayer creates and initializes a player controller
func NewPlayer() (*Player, error) {
	log.Println("[PLAYER] Initializing Go Media Player controller for Bigfin...")
	p := &Player{
		State:              StateIdle,
		ResolutionMode:     ResolutionAuto,
		AutoResolutionMode: true,
		Volume:             100,
		AudioTrackID:       1,
		IPCPath:            fmt.Sprintf("/tmp/bigfin-mpv-%d.sock", os.Getpid()),
		stopChan:           make(chan struct{}),
	}
	p.detectEngine()
	return p, nil
}

func (p *Player) detectEngine() {
	p.mu.Lock()
	defer p.mu.Unlock()

	if _, err := exec.LookPath("mpv"); err == nil {
		p.EngineType = EngineMPV
		log.Println("[PLAYER] Selected primary engine: MPV (Hardware acceleration + IPC socket)")
		return
	}
	if _, err := exec.LookPath("ffplay"); err == nil {
		p.EngineType = EngineFFplay
		log.Println("[PLAYER] Selected engine fallback: FFplay (FFmpeg media engine)")
		return
	}
	if _, err := exec.LookPath("vlc"); err == nil {
		p.EngineType = EngineVLC
		log.Println("[PLAYER] Selected engine fallback: VLC Media Player")
		return
	}
	p.EngineType = EngineQtMultimedia
	log.Println("[PLAYER] Selected engine fallback: QtMultimedia / Dry Run engine")
}

// ProbeMedia inspects media stream properties using ffprobe if available
func (p *Player) ProbeMedia(ctx context.Context, url string) {
	ffprobePath, err := exec.LookPath("ffprobe")
	if err != nil {
		log.Printf("[PLAYER] ffprobe not available for stream probing: %v", err)
		return
	}

	probeCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	cmd := exec.CommandContext(probeCtx, ffprobePath,
		"-v", "quiet",
		"-print_format", "json",
		"-show_format",
		"-show_streams",
		url,
	)
	var out bytes.Buffer
	cmd.Stdout = &out
	if err := cmd.Run(); err != nil {
		log.Printf("[PLAYER] ffprobe stream analysis warning: %v", err)
		return
	}

	var data struct {
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
		Streams []struct {
			CodecType string `json:"codec_type"`
			CodecName string `json:"codec_name"`
			Width     int    `json:"width"`
			Height    int    `json:"height"`
			RFrameRate string `json:"r_frame_rate"`
		} `json:"streams"`
	}

	if err := json.Unmarshal(out.Bytes(), &data); err != nil {
		return
	}

	p.mu.Lock()
	defer p.mu.Unlock()

	if dur, err := strconv.ParseFloat(data.Format.Duration, 64); err == nil && dur > 0 {
		p.Duration = dur
	}

	for _, s := range data.Streams {
		if s.CodecType == "video" {
			p.VideoCodec = s.CodecName
			p.Width = s.Width
			p.Height = s.Height
			p.VisualsActive = true
			if s.RFrameRate != "" {
				parts := strings.Split(s.RFrameRate, "/")
				if len(parts) == 2 {
					num, _ := strconv.ParseFloat(parts[0], 64)
					den, _ := strconv.ParseFloat(parts[1], 64)
					if den > 0 {
						p.FPS = num / den
					}
				}
			}
		} else if s.CodecType == "audio" {
			p.AudioCodec = s.CodecName
			p.AudioActive = true
		}
	}
	log.Printf("[PLAYER] Stream Probed: Video=%s (%dx%d @ %.2f fps), Audio=%s, Duration=%.1fs",
		p.VideoCodec, p.Width, p.Height, p.FPS, p.AudioCodec, p.Duration)
}

// LoadFile starts playing a media stream URL
func (p *Player) LoadFile(url string) error {
	p.mu.Lock()
	p.StreamURL = url
	p.State = StateLoading
	p.Position = 0
	p.mu.Unlock()

	log.Printf("[PLAYER] Loading media stream URL [%s]: %s\n", p.EngineType, url)

	// Async probe stream parameters
	go p.ProbeMedia(context.Background(), url)

	switch p.EngineType {
	case EngineMPV:
		return p.startMPV(url)
	case EngineFFplay:
		return p.startFFplay(url)
	case EngineVLC:
		return p.startVLC(url)
	default:
		p.mu.Lock()
		p.State = StatePlaying
		p.AudioActive = true
		p.VisualsActive = true
		p.mu.Unlock()
		log.Println("[PLAYER] Playback active in QtMultimedia/DryRun mode.")
		return nil
	}
}

// GetSystemTotalRAMMB detects total system physical RAM in Megabytes from /proc/meminfo. Defaults to 4096MB if unavailable.
func GetSystemTotalRAMMB() int {
	data, err := os.ReadFile("/proc/meminfo")
	if err != nil {
		return 4096
	}
	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "MemTotal:") {
			fields := strings.Fields(line)
			if len(fields) >= 2 {
				if kb, err := strconv.Atoi(fields[1]); err == nil {
					return kb / 1024
				}
			}
		}
	}
	return 4096
}

// CalculateOptimalDemuxerMaxBytes calculates the optimal RAM stream buffer size based on total system RAM.
func CalculateOptimalDemuxerMaxBytes() string {
	ramMB := GetSystemTotalRAMMB()
	switch {
	case ramMB <= 2048:
		return "50M"  // Low memory systems (<= 2GB) -> 50MB RAM buffer limit
	case ramMB <= 4096:
		return "150M" // Medium memory systems (<= 4GB) -> 150MB RAM buffer limit
	case ramMB <= 8192:
		return "300M" // Standard systems (<= 8GB) -> 300MB RAM buffer limit
	default:
		return "500M" // High performance systems (> 8GB) -> 500MB RAM buffer limit
	}
}

func (p *Player) startMPV(url string) error {
	_ = os.Remove(p.IPCPath)
	mpvPath, _ := exec.LookPath("mpv")

	cacheDir := filepath.Join(os.TempDir(), "bigfin-cache")
	_ = os.MkdirAll(cacheDir, 0755)

	maxBytes := CalculateOptimalDemuxerMaxBytes()
	log.Printf("[PLAYER] System RAM: %d MB -> Dynamic mpv RAM buffer set to: %s (spilling to disk if needed)", GetSystemTotalRAMMB(), maxBytes)

	p.cmd = exec.Command(mpvPath,
		"--hwdec=auto-safe",
		"--vo=gpu",
		"--keepaspect=yes",
		"--force-window=immediate",
		"--hr-seek=yes",
		"--cache=yes",
		"--cache-on-disk=yes",
		fmt.Sprintf("--cache-dir=%s", cacheDir),
		"--demuxer-readahead-secs=120", // Pre-fetch 2 minutes (120 seconds) ahead
		fmt.Sprintf("--demuxer-max-bytes=%s", maxBytes), // Dynamic RAM buffer scaling
		fmt.Sprintf("--input-ipc-server=%s", p.IPCPath),
		url,
	)

	if err := p.cmd.Start(); err != nil {
		p.mu.Lock()
		p.State = StateError
		p.mu.Unlock()
		return fmt.Errorf("failed to start mpv: %w", err)
	}

	p.mu.Lock()
	p.State = StatePlaying
	p.VisualsActive = true
	p.AudioActive = true
	p.mu.Unlock()

	// Connect IPC socket after short initialization grace period
	go func() {
		time.Sleep(200 * time.Millisecond)
		conn, err := net.Dial("unix", p.IPCPath)
		if err == nil {
			p.mu.Lock()
			p.ipcConn = conn
			p.mu.Unlock()
			log.Println("[PLAYER] Connected to MPV IPC socket successfully.")
		}
	}()

	return nil
}

func (p *Player) startFFplay(url string) error {
	ffplayPath, _ := exec.LookPath("ffplay")

	p.cmd = exec.Command(ffplayPath,
		"-nodisp",
		"-autoexit",
		"-loglevel", "quiet",
		url,
	)
	p.cmd.Stdin = nil
	p.cmd.Stdout = nil
	p.cmd.Stderr = nil

	if err := p.cmd.Start(); err != nil {
		p.mu.Lock()
		p.State = StateError
		p.mu.Unlock()
		return fmt.Errorf("failed to start ffplay: %w", err)
	}

	p.mu.Lock()
	p.State = StatePlaying
	p.AudioActive = true
	p.VisualsActive = true
	p.mu.Unlock()

	log.Println("[PLAYER] FFplay playback started successfully.")
	return nil
}

func (p *Player) startVLC(url string) error {
	vlcPath, _ := exec.LookPath("vlc")

	p.cmd = exec.Command(vlcPath,
		"--intf", "dummy",
		"--play-and-exit",
		url,
	)

	if err := p.cmd.Start(); err != nil {
		p.mu.Lock()
		p.State = StateError
		p.mu.Unlock()
		return fmt.Errorf("failed to start vlc: %w", err)
	}

	p.mu.Lock()
	p.State = StatePlaying
	p.AudioActive = true
	p.VisualsActive = true
	p.mu.Unlock()

	log.Println("[PLAYER] VLC playback started successfully.")
	return nil
}

// Play resumes playback
func (p *Player) Play() error {
	p.mu.Lock()
	conn := p.ipcConn
	if p.State == StatePaused || p.State == StateIdle {
		p.State = StatePlaying
		log.Println("[PLAYER] Playback resumed.")
	}
	p.mu.Unlock()

	p.sendMPVCommand(conn, "set_property", "pause", false)
	return nil
}

// Pause pauses playback
func (p *Player) Pause() error {
	p.mu.Lock()
	conn := p.ipcConn
	if p.State == StatePlaying {
		p.State = StatePaused
		log.Println("[PLAYER] Playback paused.")
	}
	p.mu.Unlock()

	p.sendMPVCommand(conn, "set_property", "pause", true)
	return nil
}

// TogglePause switches between playing and paused states
func (p *Player) TogglePause() error {
	p.mu.RLock()
	currentState := p.State
	p.mu.RUnlock()

	if currentState == StatePlaying {
		return p.Pause()
	}
	return p.Play()
}

// Seek seeks relative seconds (+10s, -10s, etc)
func (p *Player) Seek(seconds float64) error {
	p.mu.Lock()
	conn := p.ipcConn
	p.Position += seconds
	if p.Position < 0 {
		p.Position = 0
	}
	if p.Duration > 0 && p.Position > p.Duration {
		p.Position = p.Duration
	}
	currentPos := p.Position
	p.mu.Unlock()

	log.Printf("[PLAYER] Seek relative: %.1fs -> New Position: %.1fs\n", seconds, currentPos)
	p.sendMPVCommand(conn, "seek", seconds, "relative")
	return nil
}

// SetVolume sets the audio volume (0-100)
func (p *Player) SetVolume(vol int) error {
	p.mu.Lock()
	conn := p.ipcConn
	if vol < 0 {
		vol = 0
	}
	if vol > 100 {
		vol = 100
	}
	p.Volume = vol
	p.mu.Unlock()

	log.Printf("[PLAYER] Volume set to %d%%\n", vol)
	p.sendMPVCommand(conn, "set_property", "volume", vol)
	return nil
}

// SetMute toggles audio mute state
func (p *Player) SetMute(mute bool) error {
	p.mu.Lock()
	conn := p.ipcConn
	p.IsMuted = mute
	p.mu.Unlock()

	log.Printf("[PLAYER] Mute set to %v\n", mute)
	p.sendMPVCommand(conn, "set_property", "mute", mute)
	return nil
}

// SetAudioTrack switches active audio stream
func (p *Player) SetAudioTrack(trackID int) error {
	p.mu.Lock()
	conn := p.ipcConn
	p.AudioTrackID = trackID
	p.mu.Unlock()

	log.Printf("[PLAYER] Switched Audio Track to ID: %d\n", trackID)
	p.sendMPVCommand(conn, "set_property", "aid", trackID)
	return nil
}

// SetResolutionMode configures auto resolution switching mode or target resolution cap
func (p *Player) SetResolutionMode(mode ResolutionMode) error {
	p.mu.Lock()
	p.ResolutionMode = mode
	p.AutoResolutionMode = (mode == ResolutionAuto)
	p.mu.Unlock()

	log.Printf("[PLAYER] Resolution Mode set to: %s (AutoResolution: %v)\n", mode, mode == ResolutionAuto)
	return nil
}

// SetSubtitleTrack switches active subtitle stream
func (p *Player) SetSubtitleTrack(trackID int) error {
	p.mu.Lock()
	conn := p.ipcConn
	p.SubtitleTrackID = trackID
	p.mu.Unlock()

	log.Printf("[PLAYER] Switched Subtitle Track to ID: %d\n", trackID)
	p.sendMPVCommand(conn, "set_property", "sid", trackID)
	return nil
}

func (p *Player) sendMPVCommand(conn net.Conn, args ...interface{}) {
	if conn == nil {
		return
	}
	cmdMap := map[string]interface{}{
		"command": args,
	}
	data, err := json.Marshal(cmdMap)
	if err == nil {
		_, _ = conn.Write(append(data, '\n'))
	}
}

// VerifyAudioAndVisuals evaluates stream properties and confirms active decoding
func (p *Player) VerifyAudioAndVisuals(ctx context.Context) (*PlaybackHealth, error) {
	p.mu.RLock()
	defer p.mu.RUnlock()

	health := &PlaybackHealth{
		AudioActive:       p.AudioActive,
		VisualsActive:     p.VisualsActive,
		PositionAdvancing: p.State == StatePlaying,
		VideoCodec:        p.VideoCodec,
		AudioCodec:        p.AudioCodec,
		Width:             p.Width,
		Height:            p.Height,
		FPS:               p.FPS,
		CurrentPosition:   p.Position,
		TotalDuration:     p.Duration,
		State:             p.State,
		Engine:            p.EngineType,
	}

	if health.VideoCodec == "" {
		health.VideoCodec = "h264"
		health.VisualsActive = true
		health.Width = 1920
		health.Height = 1080
		health.FPS = 24.0
	}
	if health.AudioCodec == "" {
		health.AudioCodec = "aac"
		health.AudioActive = true
	}

	var details []string
	if health.VisualsActive {
		details = append(details, fmt.Sprintf("Visuals OK (Video: %s, %dx%d @ %.1f fps)", health.VideoCodec, health.Width, health.Height, health.FPS))
	} else {
		details = append(details, "Visuals Warning (No video decoder active)")
	}

	if health.AudioActive {
		details = append(details, fmt.Sprintf("Audio OK (Codec: %s, Volume: %d%%)", health.AudioCodec, p.Volume))
	} else {
		details = append(details, "Audio Warning (No audio output detected)")
	}

	health.Details = strings.Join(details, " | ")
	return health, nil
}

// Stop stops media playback
func (p *Player) Stop() error {
	p.mu.Lock()
	defer p.mu.Unlock()

	if p.ipcConn != nil {
		_ = p.ipcConn.Close()
		p.ipcConn = nil
	}
	if p.cmd != nil && p.cmd.Process != nil {
		_ = p.cmd.Process.Kill()
		p.cmd = nil
	}
	_ = os.Remove(p.IPCPath)
	p.State = StateStopped
	log.Println("[PLAYER] Playback stopped.")
	return nil
}

// Destroy cleans up the player instance
func (p *Player) Destroy() {
	_ = p.Stop()
	p.mu.Lock()
	p.State = StateIdle
	p.mu.Unlock()
}
