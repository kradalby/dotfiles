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
	ID       string `json:"id"`
	Name     string `json:"name"`
	Type     string `json:"type"`
	Selected bool   `json:"selected"`
	Volume   int    `json:"volume"`
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

type searchResponse struct {
	Playlists struct {
		Items  []Playlist `json:"items"`
		Total  int        `json:"total"`
		Offset int        `json:"offset"`
		Limit  int        `json:"limit"`
	} `json:"playlists"`
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

// SearchPlaylist searches for playlists matching the query string.
func (c *Client) SearchPlaylist(query string) ([]Playlist, error) {
	u := fmt.Sprintf("/api/search?type=playlist&query=%s", url.QueryEscape(query))
	var resp searchResponse
	if err := c.getJSON(u, &resp); err != nil {
		return nil, fmt.Errorf("search playlist %q: %w", query, err)
	}
	return resp.Playlists.Items, nil
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
