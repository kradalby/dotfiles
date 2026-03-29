// p3-controller is an HTTP service that orchestrates OwnTone playback
// of NRK P3 radio across AirPlay speakers with schedule-based speaker
// selection (weekday vs weekend).
package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"
	"time"

	"p3-controller/owntone"

	"github.com/chasefleming/elem-go"
	"github.com/chasefleming/elem-go/attrs"
	"github.com/chasefleming/elem-go/styles"
)

// Config is read from a JSON file passed via -config flag.
type Config struct {
	OwnToneURL   string    `json:"owntone_url"`
	Listen       string    `json:"listen"`
	PlaylistName string    `json:"playlist_name"`
	Weekday      []Speaker `json:"weekday"`
	Weekend      []Speaker `json:"weekend"`
}

// Speaker defines a target output by name with a desired volume.
type Speaker struct {
	Name   string `json:"name"`
	Volume int    `json:"volume"`
}

func main() {
	configPath := flag.String("config", "config.json", "path to JSON config file")
	flag.Parse()

	data, err := os.ReadFile(*configPath)
	if err != nil {
		log.Fatalf("reading config: %v", err)
	}

	var cfg Config
	if err := json.Unmarshal(data, &cfg); err != nil {
		log.Fatalf("parsing config: %v", err)
	}

	client := owntone.NewClient(cfg.OwnToneURL)

	page := renderPage()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html; charset=utf-8")
		fmt.Fprint(w, page)
	})
	mux.HandleFunc("GET /play", handlePlay(client, &cfg))
	mux.HandleFunc("GET /stop", handleStop(client))
	mux.HandleFunc("GET /status", handleStatus(client))

	log.Printf("p3-controller listening on %s (owntone: %s)", cfg.Listen, cfg.OwnToneURL)
	log.Fatal(http.ListenAndServe(cfg.Listen, mux))
}

// --- Handlers ---

type playResponse struct {
	Status   string   `json:"status"`
	Schedule string   `json:"schedule"`
	Speakers []string `json:"speakers"`
	Error    string   `json:"error,omitempty"`
}

func handlePlay(client *owntone.Client, cfg *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		resp := playResponse{Status: "error"}

		// Determine schedule.
		day := time.Now().Weekday()
		speakers := cfg.Weekday
		resp.Schedule = "weekday"
		if day == time.Saturday || day == time.Sunday {
			speakers = cfg.Weekend
			resp.Schedule = "weekend"
		}

		// Get all outputs and deselect them.
		outputs, err := client.GetOutputs()
		if err != nil {
			resp.Error = fmt.Sprintf("get outputs: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}
		for _, o := range outputs {
			if o.Selected {
				if err := client.SetOutput(o.ID, false, -1); err != nil {
					log.Printf("deselecting output %s (%s): %v", o.Name, o.ID, err)
				}
			}
		}

		// Select scheduled speakers by name match.
		for _, sp := range speakers {
			out, ok := findOutput(outputs, sp.Name)
			if !ok {
				log.Printf("speaker %q not found in outputs", sp.Name)
				continue
			}
			if err := client.SetOutput(out.ID, true, sp.Volume); err != nil {
				log.Printf("selecting output %s (%s): %v", out.Name, out.ID, err)
				continue
			}
			resp.Speakers = append(resp.Speakers, out.Name)
		}

		// Find playlist by name.
		playlists, err := client.SearchPlaylist(cfg.PlaylistName)
		if err != nil {
			resp.Error = fmt.Sprintf("search playlist: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}
		if len(playlists) == 0 {
			resp.Error = fmt.Sprintf("playlist %q not found", cfg.PlaylistName)
			writeJSON(w, http.StatusNotFound, resp)
			return
		}

		// Clear queue, add playlist, play.
		if err := client.ClearQueue(); err != nil {
			resp.Error = fmt.Sprintf("clear queue: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}
		if err := client.AddToQueue(playlists[0].URI); err != nil {
			resp.Error = fmt.Sprintf("add to queue: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}
		if err := client.Play(); err != nil {
			resp.Error = fmt.Sprintf("play: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}

		resp.Status = "playing"
		writeJSON(w, http.StatusOK, resp)
	}
}

func handleStop(client *owntone.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		resp := map[string]string{"status": "error"}

		if err := client.Stop(); err != nil {
			resp["error"] = fmt.Sprintf("stop: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}

		// Deselect all outputs.
		outputs, err := client.GetOutputs()
		if err != nil {
			log.Printf("deselect after stop: get outputs: %v", err)
		} else {
			for _, o := range outputs {
				if o.Selected {
					if err := client.SetOutput(o.ID, false, -1); err != nil {
						log.Printf("deselecting output %s (%s): %v", o.Name, o.ID, err)
					}
				}
			}
		}

		resp["status"] = "stopped"
		writeJSON(w, http.StatusOK, resp)
	}
}

type statusResponse struct {
	Player  *owntone.Player  `json:"player"`
	Outputs []owntone.Output `json:"outputs"`
	Error   string           `json:"error,omitempty"`
}

func handleStatus(client *owntone.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		var resp statusResponse

		player, err := client.GetPlayer()
		if err != nil {
			resp.Error = fmt.Sprintf("get player: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}
		resp.Player = player

		outputs, err := client.GetOutputs()
		if err != nil {
			resp.Error = fmt.Sprintf("get outputs: %v", err)
			writeJSON(w, http.StatusBadGateway, resp)
			return
		}
		resp.Outputs = outputs

		writeJSON(w, http.StatusOK, resp)
	}
}

// --- Helpers ---

func findOutput(outputs []owntone.Output, name string) (owntone.Output, bool) {
	lower := strings.ToLower(name)
	for _, o := range outputs {
		if strings.Contains(strings.ToLower(o.Name), lower) {
			return o, true
		}
	}
	return owntone.Output{}, false
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.WriteHeader(status)
	enc := json.NewEncoder(w)
	enc.SetIndent("", "  ")
	enc.Encode(v)
}

// --- Web UI ---

func renderPage() string {
	bodyStyle := styles.Props{
		styles.Margin:          "0",
		styles.Padding:         "2rem",
		styles.FontFamily:      "-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif",
		styles.BackgroundColor: "#1a1a2e",
		styles.Color:           "#eee",
		styles.MinHeight:       "100vh",
		styles.Display:         "flex",
		styles.FlexDirection:   "column",
		styles.AlignItems:      "center",
		styles.JustifyContent:  "center",
	}

	btnBase := styles.Props{
		styles.Padding:      "2rem 4rem",
		styles.FontSize:     "2rem",
		styles.FontWeight:   "bold",
		styles.Border:       "none",
		styles.BorderRadius: "1rem",
		styles.Cursor:       "pointer",
		styles.Color:        "#fff",
		styles.MinWidth:     "200px",
		styles.Transition:   "opacity 0.2s",
	}

	playStyle := styles.Props{}
	for k, v := range btnBase {
		playStyle[k] = v
	}
	playStyle[styles.BackgroundColor] = "#16a34a"

	stopStyle := styles.Props{}
	for k, v := range btnBase {
		stopStyle[k] = v
	}
	stopStyle[styles.BackgroundColor] = "#dc2626"

	containerStyle := styles.Props{
		styles.Display: "flex",
		styles.Gap:     "2rem",
		styles.Margin:  "2rem 0",
	}

	statusStyle := styles.Props{
		styles.FontSize:        "1.2rem",
		styles.Padding:         "1rem 2rem",
		styles.BackgroundColor: "#16213e",
		styles.BorderRadius:    "0.5rem",
		styles.MinWidth:        "300px",
		styles.TextAlign:       "center",
	}

	js := `
async function action(endpoint) {
	const statusEl = document.getElementById('status');
	statusEl.textContent = 'Working...';
	try {
		const resp = await fetch(endpoint);
		const data = await resp.json();
		if (data.error) {
			statusEl.textContent = 'Error: ' + data.error;
		} else if (data.status === 'playing') {
			statusEl.textContent = 'Playing (' + data.schedule + '): ' + (data.speakers || []).join(', ');
		} else if (data.status === 'stopped') {
			statusEl.textContent = 'Stopped';
		} else {
			statusEl.textContent = JSON.stringify(data);
		}
	} catch (e) {
		statusEl.textContent = 'Error: ' + e.message;
	}
}

async function refreshStatus() {
	try {
		const resp = await fetch('/status');
		const data = await resp.json();
		const el = document.getElementById('status');
		if (data.player) {
			const active = (data.outputs || []).filter(o => o.selected).map(o => o.name);
			el.textContent = data.player.state + (active.length ? ': ' + active.join(', ') : '');
		}
	} catch (e) {}
}

refreshStatus();
`

	page := elem.Html(nil,
		elem.Head(nil,
			elem.Title(nil, elem.Text("P3 Controller")),
			elem.Meta(attrs.Props{
				attrs.Name:    "viewport",
				attrs.Content: "width=device-width, initial-scale=1",
			}),
		),
		elem.Body(attrs.Props{attrs.Style: bodyStyle.ToInline()},
			elem.H1(
				attrs.Props{attrs.Style: styles.Props{styles.Margin: "0 0 0.5rem 0"}.ToInline()},
				elem.Text("P3 Controller"),
			),
			elem.P(
				attrs.Props{attrs.Style: styles.Props{styles.Color: "#888", styles.Margin: "0 0 1.5rem 0"}.ToInline()},
				elem.Text("NRK P3 Radio"),
			),
			elem.Div(attrs.Props{attrs.ID: "status", attrs.Style: statusStyle.ToInline()},
				elem.Text("Loading..."),
			),
			elem.Div(attrs.Props{attrs.Style: containerStyle.ToInline()},
				elem.Button(attrs.Props{
					attrs.Style: playStyle.ToInline(),
					"onclick":   "action('/play')",
				}, elem.Text("Play")),
				elem.Button(attrs.Props{
					attrs.Style: stopStyle.ToInline(),
					"onclick":   "action('/stop')",
				}, elem.Text("Stop")),
			),
			elem.Script(nil, elem.Text(js)),
		),
	)

	return page.Render()
}
