package owntone

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/stretchr/testify/require"
)

func TestNormaliseName(t *testing.T) {
	tests := []struct {
		name string
		in   string
		want string
	}{
		{
			name: "lowercases",
			in:   "NRK P3",
			want: "nrk p3",
		},
		{
			name: "hyphens become spaces",
			in:   "nrk-p3",
			want: "nrk p3",
		},
		{
			name: "nix store hash prefix stripped",
			in:   "9rwbbixzx8j3g0a2v0k1q7d5s6f8h2lm-nrk-p3",
			want: "nrk p3",
		},
		{
			// e, o, u, t are not in the Nix base-32 alphabet.
			name: "non-base32 prefix kept",
			in:   "toneexplorationsetupequalizersto-nrk-p3",
			want: "toneexplorationsetupequalizersto nrk p3",
		},
		{
			name: "short string untouched",
			in:   "p3",
			want: "p3",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			require.Equal(t, tt.want, normaliseName(tt.in))
		})
	}
}

// TestGetPlayer verifies Player parsing against an owntone-shaped
// /api/player response — in particular that shuffle and consume land
// in their own fields (shuffle used to be mis-tagged as "consume").
func TestGetPlayer(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/api/player", r.URL.Path)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"state": "play",
			"repeat": "off",
			"consume": false,
			"shuffle": true,
			"volume": 42,
			"item_id": 269,
			"item_length_ms": 278093,
			"item_progress_ms": 3674
		}`))
	}))
	defer srv.Close()

	player, err := NewClient(srv.URL).GetPlayer()
	require.NoError(t, err)
	require.Equal(t, &Player{
		State:        "play",
		RepeatMode:   "off",
		Shuffle:      true,
		Consume:      false,
		Volume:       42,
		ItemID:       269,
		ItemLength:   278093,
		ItemProgress: 3674,
	}, player)
}

func TestFindPlaylist(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		require.Equal(t, "/api/library/playlists", r.URL.Path)
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{
			"items": [
				{"id": 1, "name": "radio favourites", "uri": "library:playlist:1"},
				{"id": 2, "name": "9rwbbixzx8j3g0a2v0k1q7d5s6f8h2lm-nrk-p3", "uri": "library:playlist:2"}
			],
			"total": 2, "offset": 0, "limit": -1
		}`))
	}))
	defer srv.Close()

	client := NewClient(srv.URL)

	tests := []struct {
		name    string
		query   string
		wantURI string // empty means not found
	}{
		{
			name:    "matches through nix hash prefix",
			query:   "NRK P3",
			wantURI: "library:playlist:2",
		},
		{
			name:    "substring match",
			query:   "favourites",
			wantURI: "library:playlist:1",
		},
		{
			name:  "no match",
			query: "jazz",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			playlist, err := client.FindPlaylist(tt.query)
			require.NoError(t, err)
			if tt.wantURI == "" {
				require.Nil(t, playlist)
				return
			}
			require.NotNil(t, playlist)
			require.Equal(t, tt.wantURI, playlist.URI)
		})
	}
}
