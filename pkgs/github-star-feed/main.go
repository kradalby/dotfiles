// Command github-star-feed republishes a GitHub private dashboard feed with
// only star and follow events, so a feed reader is not drowned in
// "contributed to" noise. It polls upstream in the background and keeps what
// it saw, because GitHub's feed holds only the last few hours of activity.
package main

import (
	"bytes"
	"cmp"
	"context"
	"encoding/xml"
	"errors"
	"fmt"
	"io"
	"log/slog"
	"maps"
	"net/http"
	"net/url"
	"os"
	"os/signal"
	"slices"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/sync/errgroup"
)

const (
	envPrefix  = "GITHUB_STAR_FEED_"
	maxEntries = 200
	maxBody    = 10 << 20
)

// keep is an allowlist so event kinds GitHub adds later stay out. The kind is
// the id's type segment ("tag:github.com,2008:star/123"). No follow has been
// seen in the feed yet, and GitHub mixes snake_case and FooEvent kinds, so
// both spellings are listed; github_star_feed_upstream_entries shows the
// kinds that actually arrive.
var keep = map[string]bool{
	"star":        true,
	"follow":      true,
	"FollowEvent": true,
}

var (
	ErrNoURL   = errors.New("no feed URL, set " + envPrefix + "URL")
	ErrBadTime = errors.New("unparseable time")
	ErrStatus  = errors.New("unexpected status")
)

type text struct {
	Type string `xml:"type,attr,omitempty"`
	Body string `xml:",chardata"`
}

type link struct {
	Rel  string `xml:"rel,attr,omitempty"`
	Type string `xml:"type,attr,omitempty"`
	Href string `xml:"href,attr"`
}

type person struct {
	Name string `xml:"name"`
	URI  string `xml:"uri,omitempty"`
}

// entry carries only the fields republished; upstream's author email and
// avatar are dropped on parse.
type entry struct {
	ID      string `xml:"id"`
	Updated string `xml:"updated"`
	Link    link   `xml:"link"`
	Title   text   `xml:"title"`
	Author  person `xml:"author"`
	Content text   `xml:"content"`
}

type feed struct {
	XMLName xml.Name `xml:"http://www.w3.org/2005/Atom feed"`
	ID      string   `xml:"id"`
	Title   string   `xml:"title"`
	Updated string   `xml:"updated"`
	// Upstream's links are never copied: its self link carries the token.
	Author  *person `xml:"author,omitempty"`
	Entries []entry `xml:"entry"`
}

func kind(id string) string {
	_, rest, _ := strings.Cut(id, ",2008:")
	k, _, _ := strings.Cut(rest, "/")
	return k
}

// rfc3339 normalizes GitHub's "2006-01-02 15:04:05 -0700" entry dates, which
// are not valid Atom, to UTC RFC 3339 so they also sort as strings.
func rfc3339(s string) (string, error) {
	for _, layout := range []string{time.RFC3339, "2006-01-02 15:04:05 -0700"} {
		if t, err := time.Parse(layout, s); err == nil {
			return t.UTC().Format(time.RFC3339), nil
		}
	}
	return "", fmt.Errorf("%w: %q", ErrBadTime, s)
}

// filter returns the allowlisted entries with normalized dates, and how many
// upstream entries there were of each kind.
func filter(f *feed) ([]entry, map[string]int, error) {
	var kept []entry
	kinds := make(map[string]int)
	for _, e := range f.Entries {
		k := kind(e.ID)
		kinds[k]++
		if !keep[k] {
			continue
		}
		u, err := rfc3339(e.Updated)
		if err != nil {
			return nil, nil, fmt.Errorf("entry %s: %w", e.ID, err)
		}
		e.Updated = u
		kept = append(kept, e)
	}
	return kept, kinds, nil
}

// render writes the entries newest first. Upstream ids are kept, so a reader
// never sees an entry twice.
func render(feedID string, entries []entry) ([]byte, error) {
	sorted := slices.SortedFunc(slices.Values(entries), func(a, b entry) int {
		if c := strings.Compare(b.Updated, a.Updated); c != 0 {
			return c
		}
		return strings.Compare(a.ID, b.ID)
	})
	out := feed{
		ID:    feedID + "/stars",
		Title: "GitHub stars and follows",
		// Fixed when empty, so an idle feed renders identically every time.
		Updated: "1970-01-01T00:00:00Z",
		Author:  &person{Name: "GitHub"},
		Entries: sorted,
	}
	if len(sorted) > 0 {
		out.Updated = sorted[0].Updated
	}
	var buf bytes.Buffer
	buf.WriteString(xml.Header)
	enc := xml.NewEncoder(&buf)
	enc.Indent("", "  ")
	if err := enc.Encode(out); err != nil {
		return nil, fmt.Errorf("encoding feed: %w", err)
	}
	return buf.Bytes(), nil
}

// redact strips the URL that net/http repeats in its errors; it carries the token.
func redact(err error) error {
	if ue, ok := errors.AsType[*url.Error](err); ok {
		return ue.Err
	}
	return err
}

func fetch(ctx context.Context, client *http.Client, feedURL string) (*feed, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, feedURL, nil)
	if err != nil {
		return nil, fmt.Errorf("building request: %w", redact(err))
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, fmt.Errorf("fetching feed: %w", redact(err))
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("fetching feed: %w: %s", ErrStatus, resp.Status)
	}
	var f feed
	if err := xml.NewDecoder(io.LimitReader(resp.Body, maxBody)).Decode(&f); err != nil {
		return nil, fmt.Errorf("decoding feed: %w", err)
	}
	return &f, nil
}

type server struct {
	logger  *slog.Logger
	client  *http.Client
	feedURL string

	lastSuccess prometheus.Gauge
	upstream    *prometheus.GaugeVec

	mu      sync.Mutex
	entries map[string]entry
	body    []byte
}

func (s *server) poll(ctx context.Context) error {
	ctx, cancel := context.WithTimeout(ctx, time.Minute)
	defer cancel()
	f, err := fetch(ctx, s.client, s.feedURL)
	if err != nil {
		return err
	}
	kept, kinds, err := filter(f)
	if err != nil {
		return err
	}

	s.mu.Lock()
	defer s.mu.Unlock()
	for _, e := range kept {
		s.entries[e.ID] = e
	}
	if over := len(s.entries) - maxEntries; over > 0 {
		oldest := slices.SortedFunc(maps.Values(s.entries), func(a, b entry) int {
			return strings.Compare(a.Updated, b.Updated)
		})
		for _, e := range oldest[:over] {
			delete(s.entries, e.ID)
		}
	}
	body, err := render(f.ID, slices.Collect(maps.Values(s.entries)))
	if err != nil {
		return err
	}
	s.body = body

	s.upstream.Reset()
	for k, n := range kinds {
		s.upstream.WithLabelValues(k).Set(float64(n))
	}
	s.lastSuccess.SetToCurrentTime()
	s.logger.Info("polled feed", "upstream", len(f.Entries), "kept", len(kept), "stored", len(s.entries))
	return nil
}

func (s *server) serveFeed(w http.ResponseWriter, _ *http.Request) {
	s.mu.Lock()
	body := s.body
	s.mu.Unlock()
	if body == nil {
		http.Error(w, "feed not fetched yet", http.StatusServiceUnavailable)
		return
	}
	w.Header().Set("Content-Type", "application/atom+xml; charset=utf-8")
	w.Write(body)
}

func run(logger *slog.Logger) error {
	feedURL := os.Getenv(envPrefix + "URL")
	if feedURL == "" {
		return ErrNoURL
	}
	listenAddr := cmp.Or(os.Getenv(envPrefix+"LISTEN_ADDR"), "localhost:63469")
	interval, err := time.ParseDuration(cmp.Or(os.Getenv(envPrefix+"INTERVAL"), "10m"))
	if err != nil {
		return fmt.Errorf("parsing %sINTERVAL: %w", envPrefix, err)
	}

	registry := prometheus.NewRegistry()
	factory := promauto.With(registry)
	s := &server{
		logger:  logger,
		client:  &http.Client{},
		feedURL: feedURL,
		lastSuccess: factory.NewGauge(prometheus.GaugeOpts{
			Name: "github_star_feed_last_success_timestamp_seconds",
			Help: "Unix time of the last successful upstream poll.",
		}),
		upstream: factory.NewGaugeVec(prometheus.GaugeOpts{
			Name: "github_star_feed_upstream_entries",
			Help: "Entries per event kind in the last upstream poll, kept or not.",
		}, []string{"kind"}),
		entries: make(map[string]entry),
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	mux := http.NewServeMux()
	mux.HandleFunc("GET /feed", s.serveFeed)
	mux.Handle("GET /metrics", promhttp.HandlerFor(registry, promhttp.HandlerOpts{}))
	srv := &http.Server{
		Addr:              listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		logger.Info("listening", "addr", listenAddr, "interval", interval)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("serving: %w", err)
		}
		return nil
	})
	g.Go(func() error {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()
		for {
			if err := s.poll(gctx); err != nil {
				logger.Error("polling feed", "err", err)
			}
			select {
			case <-gctx.Done():
				return nil
			case <-ticker.C:
			}
		}
	})
	g.Go(func() error {
		<-gctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()
		return srv.Shutdown(shutdownCtx)
	})
	return g.Wait()
}

func main() {
	logger := slog.New(slog.NewTextHandler(os.Stdout, nil))
	if err := run(logger); err != nil {
		logger.Error("github-star-feed failed", "err", err)
		os.Exit(1)
	}
}
