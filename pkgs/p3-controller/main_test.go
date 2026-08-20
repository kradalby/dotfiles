package main

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"

	"p3-controller/owntone"
)

func TestExpandSpeakers(t *testing.T) {
	cfg := &Config{
		Groups: []Group{
			{Name: "Stue", Members: []string{"Stue L", "Stue R"}},
		},
	}

	tests := []struct {
		name string
		in   []Speaker
		want []Speaker
	}{
		{
			name: "group expands to members with group volume",
			in:   []Speaker{{Name: "Stue", Volume: 40}},
			want: []Speaker{{Name: "Stue L", Volume: 40}, {Name: "Stue R", Volume: 40}},
		},
		{
			name: "group name match is case-insensitive",
			in:   []Speaker{{Name: "stue", Volume: 25}},
			want: []Speaker{{Name: "Stue L", Volume: 25}, {Name: "Stue R", Volume: 25}},
		},
		{
			name: "non-group passes through",
			in:   []Speaker{{Name: "Kitchen", Volume: 30}},
			want: []Speaker{{Name: "Kitchen", Volume: 30}},
		},
		{
			name: "mixed",
			in:   []Speaker{{Name: "Kitchen", Volume: 30}, {Name: "Stue", Volume: 50}},
			want: []Speaker{
				{Name: "Kitchen", Volume: 30},
				{Name: "Stue L", Volume: 50},
				{Name: "Stue R", Volume: 50},
			},
		},
		{
			name: "empty",
			in:   nil,
			want: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			require.Equal(t, tt.want, cfg.expandSpeakers(tt.in))
		})
	}
}

func TestFindOutput(t *testing.T) {
	outputs := []owntone.Output{
		{ID: "1", Name: "Kitchen HomePod"},
		{ID: "2", Name: "Stue L"},
	}

	tests := []struct {
		name   string
		query  string
		wantID string // empty means not found
	}{
		{
			name:   "case-insensitive substring",
			query:  "kitchen",
			wantID: "1",
		},
		{
			name:   "exact name",
			query:  "Stue L",
			wantID: "2",
		},
		{
			name:  "not found",
			query: "bathroom",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			out, ok := findOutput(outputs, tt.query)
			if tt.wantID == "" {
				require.False(t, ok)
				return
			}
			require.True(t, ok)
			require.Equal(t, tt.wantID, out.ID)
		})
	}
}

func TestSpeakersForSchedule(t *testing.T) {
	cfg := &Config{
		Weekday: []Speaker{{Name: "Kitchen", Volume: 30}},
		Weekend: []Speaker{{Name: "Stue", Volume: 50}},
	}

	tests := []struct {
		name     string
		schedule string
		want     []Speaker
	}{
		{
			name:     "weekend",
			schedule: "weekend",
			want:     cfg.Weekend,
		},
		{
			name:     "weekday",
			schedule: "weekday",
			want:     cfg.Weekday,
		},
		{
			name:     "unknown falls back to weekday",
			schedule: "custom",
			want:     cfg.Weekday,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			require.Equal(t, tt.want, cfg.speakersForSchedule(tt.schedule))
		})
	}
}

// TestRoutesMethodAndCSRF verifies that mutating endpoints are
// POST-only (a forged GET 405s) and that CrossOriginProtection
// rejects cross-origin fetches while letting same-origin and
// non-browser (no fetch metadata) requests through.
func TestRoutesMethodAndCSRF(t *testing.T) {
	// Stub owntone so a permitted /stop can complete.
	owntoneSrv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		switch r.URL.Path {
		case "/api/player/stop":
			w.WriteHeader(http.StatusNoContent)
		case "/api/outputs":
			w.Header().Set("Content-Type", "application/json")
			w.Write([]byte(`{"outputs": []}`))
		default:
			http.NotFound(w, r)
		}
	}))
	defer owntoneSrv.Close()

	handler := routes(owntone.NewClient(owntoneSrv.URL), &Config{})

	tests := []struct {
		name       string
		method     string
		path       string
		headers    map[string]string
		wantStatus int
	}{
		{
			name:       "GET /play is rejected",
			method:     http.MethodGet,
			path:       "/play",
			wantStatus: http.StatusMethodNotAllowed,
		},
		{
			name:       "GET /stop is rejected",
			method:     http.MethodGet,
			path:       "/stop",
			wantStatus: http.StatusMethodNotAllowed,
		},
		{
			name:       "GET /status stays read-only",
			method:     http.MethodGet,
			path:       "/config",
			wantStatus: http.StatusOK,
		},
		{
			name:       "cross-site POST /stop is rejected",
			method:     http.MethodPost,
			path:       "/stop",
			headers:    map[string]string{"Sec-Fetch-Site": "cross-site"},
			wantStatus: http.StatusForbidden,
		},
		{
			name:       "same-origin POST /stop is allowed",
			method:     http.MethodPost,
			path:       "/stop",
			headers:    map[string]string{"Sec-Fetch-Site": "same-origin"},
			wantStatus: http.StatusOK,
		},
		{
			name:       "non-browser POST /stop is allowed",
			method:     http.MethodPost,
			path:       "/stop",
			wantStatus: http.StatusOK,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := httptest.NewRequest(tt.method, tt.path, strings.NewReader(""))
			for k, v := range tt.headers {
				req.Header.Set(k, v)
			}
			rec := httptest.NewRecorder()
			handler.ServeHTTP(rec, req)
			require.Equal(t, tt.wantStatus, rec.Code)
		})
	}
}

// Apple Shortcuts' "JSON body with no fields" sends `{}`; it must take the
// scheduled-play path, not be rejected as "no speakers specified".
func TestPlayEmptyJSONMeansSchedule(t *testing.T) {
	owntoneSrv := httptest.NewServer(http.NotFoundHandler())
	defer owntoneSrv.Close()
	handler := routes(owntone.NewClient(owntoneSrv.URL), &Config{})

	for _, body := range []string{"{}", "null", ""} {
		req := httptest.NewRequest(http.MethodPost, "/play", strings.NewReader(body))
		rec := httptest.NewRecorder()
		handler.ServeHTTP(rec, req)
		// The stub has no playlists, so schedule play fails upstream — but it
		// must NOT be the 400 "no speakers specified" rejection.
		require.NotEqual(t, http.StatusBadRequest, rec.Code, "body %q", body)
	}
}
