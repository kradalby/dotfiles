// Package owntone provides a client for the OwnTone server JSON API.
//
// API reference: https://owntone.github.io/owntone-server/json-api/
package owntone

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"strings"
	"time"
)

// Client talks to the OwnTone JSON API.
type Client struct {
	BaseURL    string
	HTTPClient *http.Client
}

// NewClient returns a Client for the given OwnTone base URL
// (e.g. "http://localhost:3689").
func NewClient(baseURL string) *Client {
	return &Client{
		BaseURL: strings.TrimRight(baseURL, "/"),
		HTTPClient: &http.Client{
			Timeout: 10 * time.Second,
		},
	}
}

// Output represents an OwnTone audio output (speaker).
type Output struct {
	ID           string `json:"id"`
	Name         string `json:"name"`
	Type         string `json:"type"`
	Selected     bool   `json:"selected"`
	Volume       int    `json:"volume"`
	RequiresAuth bool   `json:"requires_auth"`
	NeedsAuthKey bool   `json:"needs_auth_key"`
}

type outputsResponse struct {
	Outputs []Output `json:"outputs"`
}

// Player represents the OwnTone player state.
type Player struct {
	State        string `json:"state"`
	RepeatMode   string `json:"repeat"`
	ShuffleMode  bool   `json:"consume"`
	Volume       int    `json:"volume"`
	ItemID       int    `json:"item_id"`
	ItemLength   int    `json:"item_length_ms"`
	ItemProgress int    `json:"item_progress_ms"`
}

// Playlist represents an OwnTone playlist.
type Playlist struct {
	ID   int    `json:"id"`
	Name string `json:"name"`
	URI  string `json:"uri"`
}

type playlistsResponse struct {
	Items  []Playlist `json:"items"`
	Total  int        `json:"total"`
	Offset int        `json:"offset"`
	Limit  int        `json:"limit"`
}

// GetOutputs returns all configured outputs (speakers).
func (c *Client) GetOutputs() ([]Output, error) {
	var resp outputsResponse
	if err := c.getJSON("/api/outputs", &resp); err != nil {
		return nil, fmt.Errorf("get outputs: %w", err)
	}
	return resp.Outputs, nil
}

// SetOutput enables/disables an output and optionally sets its volume.
// If volume is negative, the volume is not changed.
func (c *Client) SetOutput(id string, selected bool, volume int) error {
	body := map[string]any{"selected": selected}
	if volume >= 0 {
		body["volume"] = volume
	}
	if err := c.putJSON(fmt.Sprintf("/api/outputs/%s", id), body); err != nil {
		return fmt.Errorf("set output %s: %w", id, err)
	}
	return nil
}

// GetPlayer returns the current player state.
func (c *Client) GetPlayer() (*Player, error) {
	var p Player
	if err := c.getJSON("/api/player", &p); err != nil {
		return nil, fmt.Errorf("get player: %w", err)
	}
	return &p, nil
}

// Play starts playback.
func (c *Client) Play() error {
	return c.put("/api/player/play")
}

// Stop stops playback.
func (c *Client) Stop() error {
	return c.put("/api/player/stop")
}

// ClearQueue removes all items from the play queue.
func (c *Client) ClearQueue() error {
	return c.put("/api/queue/clear")
}

// AddToQueue adds items to the queue by URI
// (e.g. "library:playlist:1").
func (c *Client) AddToQueue(uri string) error {
	u := fmt.Sprintf("/api/queue/items/add?uris=%s", url.QueryEscape(uri))
	return c.post(u)
}

// GetPlaylists returns all playlists from the library.
// This is more reliable than the search endpoint, which uses
// full-text search and may miss playlists with short names.
func (c *Client) GetPlaylists() ([]Playlist, error) {
	var resp playlistsResponse
	if err := c.getJSON("/api/library/playlists", &resp); err != nil {
		return nil, fmt.Errorf("get playlists: %w", err)
	}
	return resp.Items, nil
}

// FindPlaylist lists all playlists and returns the first one whose
// normalised name contains the normalised query. Normalisation
// lowercases the string and replaces hyphens with spaces, and strips
// Nix store hash prefixes (32-char hex + "-") so that a playlist
// named "9rwbbix…-nrk-p3" will match the query "NRK P3".
func (c *Client) FindPlaylist(query string) (*Playlist, error) {
	playlists, err := c.GetPlaylists()
	if err != nil {
		return nil, err
	}
	norm := normaliseName(query)
	for _, p := range playlists {
		if strings.Contains(normaliseName(p.Name), norm) {
			return &p, nil
		}
	}
	return nil, nil
}

// normaliseName lowercases, replaces hyphens with spaces, and strips
// a leading Nix store hash prefix (32 hex chars followed by a dash).
func normaliseName(s string) string {
	s = strings.ToLower(s)
	s = strings.ReplaceAll(s, "-", " ")
	// Strip Nix store hash prefix: 32 hex chars + space (was dash).
	if len(s) > 33 && s[32] == ' ' && isHex(s[:32]) {
		s = s[33:]
	}
	return s
}

// isHex reports whether every byte in s is a lowercase hex digit.
func isHex(s string) bool {
	for i := 0; i < len(s); i++ {
		c := s[i]
		if !((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f')) {
			return false
		}
	}
	return true
}

// --- HTTP helpers ---

func (c *Client) getJSON(path string, dst any) error {
	resp, err := c.HTTPClient.Get(c.BaseURL + path)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("GET %s: %s: %s", path, resp.Status, body)
	}
	return json.NewDecoder(resp.Body).Decode(dst)
}

func (c *Client) putJSON(path string, body any) error {
	data, err := json.Marshal(body)
	if err != nil {
		return err
	}
	req, err := http.NewRequest(http.MethodPut, c.BaseURL+path, bytes.NewReader(data))
	if err != nil {
		return err
	}
	req.Header.Set("Content-Type", "application/json")
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("PUT %s: %s: %s", path, resp.Status, respBody)
	}
	return nil
}

func (c *Client) put(path string) error {
	req, err := http.NewRequest(http.MethodPut, c.BaseURL+path, nil)
	if err != nil {
		return err
	}
	resp, err := c.HTTPClient.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("PUT %s: %s: %s", path, resp.Status, body)
	}
	return nil
}

func (c *Client) post(path string) error {
	resp, err := c.HTTPClient.Post(c.BaseURL+path, "", nil)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("POST %s: %s: %s", path, resp.Status, body)
	}
	return nil
}
