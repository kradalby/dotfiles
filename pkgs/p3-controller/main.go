// p3-controller is an HTTP service that orchestrates OwnTone playback
// of NRK P3 radio across AirPlay speakers with schedule-based speaker
// selection (weekday vs weekend).
package main

import (
	"context"
	_ "embed"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"net"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"golang.org/x/sync/errgroup"

	"p3-controller/owntone"
)

//go:embed shortcuts/play-p3.shortcut
var playP3Shortcut []byte

//go:embed shortcuts/stop-p3.shortcut
var stopP3Shortcut []byte

// Config is read from a JSON file passed via -config flag.
type Config struct {
	OwnToneURL   string    `json:"owntone_url"`
	Listen       string    `json:"listen"`
	PlaylistName string    `json:"playlist_name"`
	Weekday      []Speaker `json:"weekday"`
	Weekend      []Speaker `json:"weekend"`
	Groups       []Group   `json:"groups"`
	HAP          HAPConfig `json:"hap"`
}

// Speaker defines a target output by name with a desired volume.
type Speaker struct {
	Name   string `json:"name"`
	Volume int    `json:"volume"`
}

// Group defines a set of OwnTone outputs that should be treated
// as a single speaker (e.g. a stereo pair).
type Group struct {
	Name    string   `json:"name"`
	Members []string `json:"members"`
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
	mux.HandleFunc("POST /play", handlePlayCustom(client, &cfg))
	mux.HandleFunc("GET /stop", handleStop(client))
	mux.HandleFunc("GET /status", handleStatus(client))
	mux.HandleFunc("GET /config", handleConfig(&cfg))
	mux.HandleFunc("PUT /output/{id}", handleSetOutput(client))
	mux.HandleFunc("GET /shortcut/{name}", handleShortcut())

	if err := run(&cfg, client, mux); err != nil {
		log.Fatal(err)
	}
}

// run owns the process lifecycle: signal-driven root context, an
// errgroup that supervises the HTTP server (and HomeKit accessory if
// enabled), and bounded graceful shutdown. Returns when every
// goroutine has unwound, or with the first non-nil error from a
// supervised component.
func run(cfg *Config, client *owntone.Client, mux *http.ServeMux) error {
	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	g, gctx := errgroup.WithContext(ctx)

	srv := &http.Server{
		Addr:    cfg.Listen,
		Handler: mux,
		BaseContext: func(net.Listener) context.Context {
			return gctx
		},
	}

	g.Go(func() error {
		log.Printf("p3-controller listening on %s (owntone: %s)", cfg.Listen, cfg.OwnToneURL)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("http server: %w", err)
		}
		return nil
	})

	if cfg.HAP.Enabled {
		g.Go(func() error {
			return runHAP(gctx, client, cfg)
		})
	}

	g.Go(func() error {
		<-gctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		if err := srv.Shutdown(shutdownCtx); err != nil {
			log.Printf("http shutdown: %v", err)
		}
		return nil
	})

	return g.Wait()
}

// --- Play logic ---

type playResponse struct {
	Status   string   `json:"status"`
	Schedule string   `json:"schedule"`
	Speakers []string `json:"speakers"`
	Error    string   `json:"error,omitempty"`
}

// expandSpeakers resolves group names to individual OwnTone output names.
// A speaker whose name matches a group expands to all group members;
// otherwise the name is passed through as-is.
func (cfg *Config) expandSpeakers(speakers []Speaker) []Speaker {
	groupMap := make(map[string][]string)
	for _, g := range cfg.Groups {
		groupMap[strings.ToLower(g.Name)] = g.Members
	}

	var expanded []Speaker
	for _, sp := range speakers {
		if members, ok := groupMap[strings.ToLower(sp.Name)]; ok {
			for _, m := range members {
				expanded = append(expanded, Speaker{Name: m, Volume: sp.Volume})
			}
		} else {
			expanded = append(expanded, sp)
		}
	}
	return expanded
}

func executePlay(client *owntone.Client, cfg *Config, speakers []Speaker, schedule string) (playResponse, int) {
	resp := playResponse{Status: "error", Schedule: schedule}

	expanded := cfg.expandSpeakers(speakers)

	// Get all outputs and deselect them.
	outputs, err := client.GetOutputs()
	if err != nil {
		resp.Error = fmt.Sprintf("get outputs: %v", err)
		return resp, http.StatusBadGateway
	}
	for _, o := range outputs {
		if o.Selected {
			if err := client.SetOutput(o.ID, false, -1); err != nil {
				log.Printf("deselecting output %s (%s): %v", o.Name, o.ID, err)
			}
		}
	}

	// Select requested speakers by name match.
	for _, sp := range expanded {
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

	// Find playlist by name, retrying a few times in case OwnTone
	// is still scanning the library after a restart.
	var playlist *owntone.Playlist
	const maxAttempts = 3
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		playlist, err = client.FindPlaylist(cfg.PlaylistName)
		if err != nil {
			resp.Error = fmt.Sprintf("find playlist: %v", err)
			return resp, http.StatusBadGateway
		}
		if playlist != nil {
			break
		}
		if attempt < maxAttempts {
			log.Printf("playlist %q not found (attempt %d/%d), retrying…", cfg.PlaylistName, attempt, maxAttempts)
			time.Sleep(time.Duration(attempt) * 3 * time.Second)
		}
	}
	if playlist == nil {
		resp.Error = fmt.Sprintf("playlist %q not found after %d attempts", cfg.PlaylistName, maxAttempts)
		return resp, http.StatusNotFound
	}

	// Clear queue, add playlist, play.
	if err := client.ClearQueue(); err != nil {
		resp.Error = fmt.Sprintf("clear queue: %v", err)
		return resp, http.StatusBadGateway
	}
	if err := client.AddToQueue(playlist.URI); err != nil {
		resp.Error = fmt.Sprintf("add to queue: %v", err)
		return resp, http.StatusBadGateway
	}
	if err := client.Play(); err != nil {
		resp.Error = fmt.Sprintf("play: %v", err)
		return resp, http.StatusBadGateway
	}

	resp.Status = "playing"
	return resp, http.StatusOK
}

// --- Handlers ---

// scheduleForNow returns "weekday" or "weekend" based on the current
// day. Shared between the HTTP handler and the HomeKit accessory so
// both surfaces apply the same profile.
func scheduleForNow() string {
	day := time.Now().Weekday()
	if day == time.Saturday || day == time.Sunday {
		return "weekend"
	}
	return "weekday"
}

// speakersForSchedule returns the configured speakers for the named
// schedule.
func (cfg *Config) speakersForSchedule(schedule string) []Speaker {
	if schedule == "weekend" {
		return cfg.Weekend
	}
	return cfg.Weekday
}

func handlePlay(client *owntone.Client, cfg *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		schedule := scheduleForNow()
		resp, status := executePlay(client, cfg, cfg.speakersForSchedule(schedule), schedule)
		writeJSON(w, status, resp)
	}
}

func handlePlayCustom(client *owntone.Client, cfg *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		var req struct {
			Speakers []Speaker `json:"speakers"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, playResponse{
				Status: "error",
				Error:  fmt.Sprintf("invalid request body: %v", err),
			})
			return
		}
		if len(req.Speakers) == 0 {
			writeJSON(w, http.StatusBadRequest, playResponse{
				Status: "error",
				Error:  "no speakers specified",
			})
			return
		}

		resp, status := executePlay(client, cfg, req.Speakers, "custom")
		writeJSON(w, status, resp)
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

type configResponse struct {
	Profiles       map[string][]Speaker `json:"profiles"`
	Groups         []Group              `json:"groups"`
	CurrentProfile string               `json:"current_profile"`
}

func handleConfig(cfg *Config) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		profile := "weekday"
		day := time.Now().Weekday()
		if day == time.Saturday || day == time.Sunday {
			profile = "weekend"
		}

		writeJSON(w, http.StatusOK, configResponse{
			Profiles: map[string][]Speaker{
				"weekday": cfg.Weekday,
				"weekend": cfg.Weekend,
			},
			Groups:         cfg.Groups,
			CurrentProfile: profile,
		})
	}
}

func handleSetOutput(client *owntone.Client) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")

		id := r.PathValue("id")

		var req struct {
			Selected *bool `json:"selected"`
			Volume   *int  `json:"volume"`
		}
		if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
			writeJSON(w, http.StatusBadRequest, map[string]string{
				"error": fmt.Sprintf("invalid request body: %v", err),
			})
			return
		}

		selected := false
		if req.Selected != nil {
			selected = *req.Selected
		}
		volume := -1
		if req.Volume != nil {
			volume = *req.Volume
		}

		if err := client.SetOutput(id, selected, volume); err != nil {
			writeJSON(w, http.StatusBadGateway, map[string]string{
				"error": fmt.Sprintf("set output: %v", err),
			})
			return
		}

		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	}
}

// --- Shortcuts ---

// Signed Apple Shortcuts are embedded at build time. To regenerate:
//
//  1. Create unsigned plists with the target URL baked in.
//  2. Sign on macOS:  shortcuts sign -m anyone -i unsigned.shortcut -o signed.shortcut
//  3. Replace the files in shortcuts/.

var shortcutFiles = map[string]struct {
	Name string
	Data []byte
}{
	"play-p3": {Name: "Play P3", Data: playP3Shortcut},
	"stop-p3": {Name: "Stop P3", Data: stopP3Shortcut},
}

func handleShortcut() http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		name := strings.TrimSuffix(r.PathValue("name"), ".shortcut")

		sc, ok := shortcutFiles[name]
		if !ok {
			http.NotFound(w, r)
			return
		}

		w.Header().Set("Content-Type", "application/octet-stream")
		w.Header().Set("Content-Disposition", fmt.Sprintf(`attachment; filename="%s.shortcut"`, sc.Name))
		w.Write(sc.Data)
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
	return `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>P3 Controller</title>
<style>
* { box-sizing: border-box; margin: 0; padding: 0; }
body {
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
  background: #1a1a2e;
  color: #eee;
  min-height: 100dvh;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  -webkit-text-size-adjust: 100%;
}
h1 { font-size: 1.4rem; margin-bottom: 0.15rem; }
.subtitle { color: #888; font-size: 0.85rem; margin-bottom: 0.75rem; }

.status-bar {
  background: #16213e;
  border-radius: 0.5rem;
  padding: 0.5rem 1rem;
  width: 100%;
  max-width: 360px;
  text-align: center;
  font-size: 0.9rem;
  min-height: 2.2rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}

.profiles {
  display: flex;
  gap: 0.5rem;
  margin-bottom: 0.75rem;
}
.profile-btn {
  padding: 0.4rem 1.2rem;
  font-size: 0.85rem;
  font-weight: 600;
  border: 2px solid #333;
  border-radius: 0.5rem;
  background: transparent;
  color: #aaa;
  cursor: pointer;
  transition: all 0.15s;
}
.profile-btn.active {
  border-color: #4f8cff;
  color: #fff;
  background: #1e3a5f;
}

.speakers {
  width: 100%;
  max-width: 360px;
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  margin-bottom: 0.75rem;
}
.speaker-row {
  display: grid;
  grid-template-columns: auto 1fr;
  align-items: center;
  gap: 0.5rem;
  background: #16213e;
  border-radius: 0.5rem;
  padding: 0.45rem 0.6rem;
}
.speaker-row label {
  font-size: 0.85rem;
  white-space: nowrap;
  cursor: pointer;
  display: flex;
  align-items: center;
  gap: 0.35rem;
}
.speaker-row input[type="checkbox"] {
  width: 1.1rem;
  height: 1.1rem;
  accent-color: #4f8cff;
}
.volume-wrap {
  display: flex;
  align-items: center;
  gap: 0.3rem;
}
.volume-wrap input[type="range"] {
  flex: 1;
  min-width: 0;
  height: 22px;
  accent-color: #4f8cff;
  touch-action: manipulation;
}
.volume-wrap .vol-num {
  font-size: 0.75rem;
  color: #888;
  min-width: 1.5rem;
  text-align: right;
}

.actions {
  display: flex;
  gap: 0.75rem;
}
.action-btn {
  padding: 0.9rem 2rem;
  font-size: 1.1rem;
  font-weight: bold;
  border: none;
  border-radius: 0.75rem;
  cursor: pointer;
  color: #fff;
  min-width: 120px;
  transition: opacity 0.15s;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 0.5rem;
  touch-action: manipulation;
}
.action-btn:disabled { opacity: 0.5; cursor: not-allowed; }
.action-btn.play { background: #16a34a; }
.action-btn.stop { background: #dc2626; }

.spinner {
  display: inline-block;
  width: 1em;
  height: 1em;
  border: 2px solid rgba(255,255,255,0.3);
  border-top-color: #fff;
  border-radius: 50%;
  animation: spin 0.6s linear infinite;
}
.spinner.sm { width: 0.75em; height: 0.75em; border-width: 1.5px; }
@keyframes spin { to { transform: rotate(360deg); } }

.shortcuts {
  margin-top: 0.75rem;
  display: flex;
  gap: 0.5rem;
}
.shortcut-link {
  font-size: 0.75rem;
  color: #4f8cff;
  text-decoration: none;
  padding: 0.3rem 0.6rem;
  border: 1px solid #333;
  border-radius: 0.4rem;
  transition: border-color 0.15s;
}
.shortcut-link:hover { border-color: #4f8cff; }
</style>
</head>
<body>
<h1>P3 Controller</h1>
<p class="subtitle">NRK P3 Radio</p>

<div class="status-bar" id="status"><span class="spinner"></span> Loading&hellip;</div>

<div class="profiles" id="profiles"></div>

<div class="speakers" id="speakers"></div>

<div class="actions">
  <button class="action-btn play" id="playBtn" onclick="doPlay()" disabled>Play</button>
  <button class="action-btn stop" id="stopBtn" onclick="doStop()" disabled>Stop</button>
</div>

<div class="shortcuts">
  <a class="shortcut-link" href="/shortcut/play-p3.shortcut">Add "Play P3" to Siri</a>
  <a class="shortcut-link" href="/shortcut/stop-p3.shortcut">Add "Stop P3" to Siri</a>
</div>

<script>
let configData = null;
let outputsData = [];
let activeProfile = null;
let busy = false;

async function init() {
  try {
    const [cfgResp, statusResp] = await Promise.all([
      fetch('/config').then(r => r.json()),
      fetch('/status').then(r => r.json()),
    ]);
    configData = cfgResp;
    if (statusResp.outputs) outputsData = statusResp.outputs;

    renderProfiles();
    renderSpeakers();

    // If currently playing, reflect actual state; otherwise apply today's profile.
    if (statusResp.player && statusResp.player.state === 'playing') {
      reflectLiveState();
      updateStatus(statusResp);
    } else {
      applyProfile(configData.current_profile);
      updateStatus(statusResp);
    }

    document.getElementById('playBtn').disabled = false;
    document.getElementById('stopBtn').disabled = false;
  } catch (e) {
    document.getElementById('status').textContent = 'Error: ' + e.message;
  }
  setInterval(refreshStatus, 5000);
}

// --- Profiles ---

function renderProfiles() {
  const el = document.getElementById('profiles');
  el.innerHTML = '';
  for (const name of ['weekday', 'weekend']) {
    const btn = document.createElement('button');
    btn.className = 'profile-btn';
    btn.textContent = name.charAt(0).toUpperCase() + name.slice(1);
    btn.onclick = () => applyProfile(name);
    btn.dataset.profile = name;
    el.appendChild(btn);
  }
}

function applyProfile(name) {
  activeProfile = name;
  // Highlight active button.
  document.querySelectorAll('.profile-btn').forEach(b => {
    b.classList.toggle('active', b.dataset.profile === name);
  });

  const speakers = configData.profiles[name] || [];
  const speakerMap = {};
  speakers.forEach(s => { speakerMap[s.name.toLowerCase()] = s.volume; });

  // Build group lookup.
  const groupMembers = {};
  (configData.groups || []).forEach(g => {
    groupMembers[g.name.toLowerCase()] = g.members;
  });

  // Uncheck all, then check profile speakers.
  document.querySelectorAll('.speaker-row').forEach(row => {
    const displayName = row.dataset.name;
    const key = displayName.toLowerCase();
    const cb = row.querySelector('input[type="checkbox"]');
    const slider = row.querySelector('input[type="range"]');
    const volNum = row.querySelector('.vol-num');

    if (key in speakerMap) {
      cb.checked = true;
      slider.value = speakerMap[key];
      volNum.textContent = speakerMap[key];
    } else {
      cb.checked = false;
    }
  });
}

// --- Speakers ---

function renderSpeakers() {
  const el = document.getElementById('speakers');
  el.innerHTML = '';

  // Build group lookup: member name -> group name.
  const memberToGroup = {};
  const groupNames = new Set();
  (configData.groups || []).forEach(g => {
    groupNames.add(g.name.toLowerCase());
    g.members.forEach(m => {
      memberToGroup[m.toLowerCase()] = g.name;
    });
  });

  // Determine which outputs to show.
  // Hide auth-required outputs.
  // Merge grouped outputs into a single row.
  const seen = new Set();
  const rows = [];

  for (const o of outputsData) {
    if (o.requires_auth || o.needs_auth_key) continue;

    const lowerName = o.name.toLowerCase();
    if (lowerName in memberToGroup) {
      const groupName = memberToGroup[lowerName];
      if (seen.has(groupName.toLowerCase())) continue;
      seen.add(groupName.toLowerCase());
      // Find all member outputs.
      const group = configData.groups.find(g => g.name.toLowerCase() === groupName.toLowerCase());
      const memberOutputs = group.members
        .map(m => outputsData.find(out => out.name.toLowerCase() === m.toLowerCase()))
        .filter(Boolean);
      rows.push({
        displayName: groupName,
        outputs: memberOutputs,
        volume: memberOutputs.length > 0 ? memberOutputs[0].volume : 50,
        selected: memberOutputs.some(o => o.selected),
      });
    } else {
      rows.push({
        displayName: o.name,
        outputs: [o],
        volume: o.volume,
        selected: o.selected,
      });
    }
  }

  for (const row of rows) {
    const div = document.createElement('div');
    div.className = 'speaker-row';
    div.dataset.name = row.displayName;
    div.dataset.outputIds = JSON.stringify(row.outputs.map(o => o.id));

    const label = document.createElement('label');
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = row.selected;
    label.appendChild(cb);
    label.appendChild(document.createTextNode(' ' + row.displayName));

    const volWrap = document.createElement('div');
    volWrap.className = 'volume-wrap';
    const slider = document.createElement('input');
    slider.type = 'range';
    slider.min = '0';
    slider.max = '100';
    slider.value = row.volume;
    const volNum = document.createElement('span');
    volNum.className = 'vol-num';
    volNum.textContent = row.volume;

    let debounceTimer = null;
    slider.addEventListener('input', () => {
      volNum.textContent = slider.value;
      // Live volume adjustment if checked.
      if (cb.checked) {
        clearTimeout(debounceTimer);
        debounceTimer = setTimeout(() => {
          const ids = JSON.parse(div.dataset.outputIds);
          ids.forEach(id => {
            fetch('/output/' + id, {
              method: 'PUT',
              headers: {'Content-Type': 'application/json'},
              body: JSON.stringify({selected: true, volume: parseInt(slider.value)}),
            }).catch(() => {});
          });
        }, 300);
      }
    });

    volWrap.appendChild(slider);
    volWrap.appendChild(volNum);
    div.appendChild(label);
    div.appendChild(volWrap);
    el.appendChild(div);
  }
}

function reflectLiveState() {
  // Reflect what OwnTone currently has selected.
  const memberToGroup = {};
  (configData.groups || []).forEach(g => {
    g.members.forEach(m => { memberToGroup[m.toLowerCase()] = g.name; });
  });

  document.querySelectorAll('.speaker-row').forEach(row => {
    const ids = JSON.parse(row.dataset.outputIds);
    const outputs = ids.map(id => outputsData.find(o => o.id === id)).filter(Boolean);
    const cb = row.querySelector('input[type="checkbox"]');
    const slider = row.querySelector('input[type="range"]');
    const volNum = row.querySelector('.vol-num');

    const anySelected = outputs.some(o => o.selected);
    cb.checked = anySelected;
    if (anySelected) {
      const vol = outputs.find(o => o.selected).volume;
      slider.value = vol;
      volNum.textContent = vol;
    }
  });

  // Highlight matching profile button if state matches a profile.
  document.querySelectorAll('.profile-btn').forEach(b => b.classList.remove('active'));
}

// --- Actions ---

async function doPlay() {
  if (busy) return;
  busy = true;
  const playBtn = document.getElementById('playBtn');
  const stopBtn = document.getElementById('stopBtn');
  playBtn.disabled = true;
  stopBtn.disabled = true;
  playBtn.innerHTML = '<span class="spinner"></span> Starting\u2026';

  const speakers = [];
  document.querySelectorAll('.speaker-row').forEach(row => {
    const cb = row.querySelector('input[type="checkbox"]');
    if (cb.checked) {
      const slider = row.querySelector('input[type="range"]');
      speakers.push({name: row.dataset.name, volume: parseInt(slider.value)});
    }
  });

  try {
    const resp = await fetch('/play', {
      method: 'POST',
      headers: {'Content-Type': 'application/json'},
      body: JSON.stringify({speakers}),
    });
    const data = await resp.json();
    showActionResult(data);
  } catch (e) {
    document.getElementById('status').textContent = 'Error: ' + e.message;
  }
  playBtn.innerHTML = 'Play';
  playBtn.disabled = false;
  stopBtn.disabled = false;
  busy = false;
}

async function doStop() {
  if (busy) return;
  busy = true;
  const playBtn = document.getElementById('playBtn');
  const stopBtn = document.getElementById('stopBtn');
  playBtn.disabled = true;
  stopBtn.disabled = true;
  stopBtn.innerHTML = '<span class="spinner"></span> Stopping\u2026';

  try {
    const resp = await fetch('/stop');
    const data = await resp.json();
    showActionResult(data);
  } catch (e) {
    document.getElementById('status').textContent = 'Error: ' + e.message;
  }
  stopBtn.innerHTML = 'Stop';
  playBtn.disabled = false;
  stopBtn.disabled = false;
  busy = false;
}

function showActionResult(data) {
  const el = document.getElementById('status');
  if (data.error) {
    el.textContent = 'Error: ' + data.error;
  } else if (data.status === 'playing') {
    el.textContent = 'Playing: ' + (data.speakers || []).join(', ');
  } else if (data.status === 'stopped') {
    el.textContent = 'Stopped';
  } else {
    el.textContent = JSON.stringify(data);
  }
}

// --- Status polling ---

async function refreshStatus() {
  try {
    const resp = await fetch('/status');
    const data = await resp.json();
    if (data.outputs) outputsData = data.outputs;
    updateStatus(data);
  } catch (e) {}
}

function updateStatus(data) {
  const el = document.getElementById('status');
  if (data.error) {
    el.textContent = 'Error: ' + data.error;
    return;
  }
  if (data.player) {
    const state = data.player.state;
    const active = (data.outputs || [])
      .filter(o => o.selected && !o.requires_auth && !o.needs_auth_key)
      .map(o => o.name);

    // Collapse group members into group name.
    const memberToGroup = {};
    (configData.groups || []).forEach(g => {
      g.members.forEach(m => { memberToGroup[m.toLowerCase()] = g.name; });
    });
    const seen = new Set();
    const display = [];
    for (const name of active) {
      const gn = memberToGroup[name.toLowerCase()];
      const displayName = gn || name;
      if (!seen.has(displayName.toLowerCase())) {
        seen.add(displayName.toLowerCase());
        display.push(displayName);
      }
    }

    if (state === 'playing' || state === 'paused') {
      el.innerHTML = '<span style="color:#4ade80">\u25CF</span> ' +
        state.charAt(0).toUpperCase() + state.slice(1) +
        (display.length ? ': ' + display.join(', ') : '');
    } else {
      el.textContent = state.charAt(0).toUpperCase() + state.slice(1);
    }
  }
}

init();
</script>
</body>
</html>`
}
