// WebSocket support for OwnTone push events.
//
// OwnTone exposes a notification WebSocket that pushes a small JSON
// payload like {"notify":["player"]} whenever player/queue/output
// state changes. We subscribe to "player" and refetch /api/player
// on each event so HomeKit reflects external state changes within
// ~1s, with no polling.

package owntone

import (
	"context"
	"fmt"
	"log"
	"net/url"
	"slices"
	"strings"
	"time"

	"golang.org/x/net/websocket"
)

type configResponse struct {
	WebSocketPort int `json:"websocket_port"`
}

// GetWebSocketPort returns the port owntone advertises for its
// notification WebSocket. Returns 0 if owntone was built without
// libwebsockets (in which case no WS is available).
func (c *Client) GetWebSocketPort() (int, error) {
	var resp configResponse
	if err := c.getJSON("/api/config", &resp); err != nil {
		return 0, fmt.Errorf("get config: %w", err)
	}
	return resp.WebSocketPort, nil
}

// notifyEvent is the payload owntone sends on the notify channel:
// {"notify":["player","queue",...]}. The slice lists which categories
// changed; payload is intentionally empty — clients refetch the
// affected REST endpoint.
type notifyEvent struct {
	Notify []string `json:"notify"`
}

// SubscribePlayer opens a WebSocket to owntone's notify endpoint,
// subscribes to player events, and invokes onChange for each event
// (including the initial subscribe). The connection is reestablished
// with exponential backoff (1s → 30s) until ctx is cancelled.
//
// onChange is called from the WS reader goroutine; keep it short and
// non-blocking — fetch state on a separate goroutine if needed.
//
// Returns when ctx is cancelled. Any read/dial errors are logged and
// trigger reconnect; they are not returned.
func (c *Client) SubscribePlayer(ctx context.Context, onChange func()) error {
	backoff := time.Second
	const maxBackoff = 30 * time.Second

	for {
		if ctx.Err() != nil {
			return nil
		}

		// Discover the websocket port on every iteration so a
		// transient owntone outage at startup (the http port not yet
		// bound when p3-controller queries) recovers via the same
		// reconnect loop as a mid-run drop.
		wsPort, err := c.GetWebSocketPort()
		if err == nil && wsPort == 0 {
			err = fmt.Errorf("owntone built without websocket support")
		}
		var wsURL string
		if err == nil {
			wsURL, err = buildWSURL(c.BaseURL, wsPort)
		}
		if err == nil {
			err = runOnce(ctx, wsURL, onChange)
		}

		if ctx.Err() != nil {
			return nil
		}
		if err != nil {
			log.Printf("owntone ws: %v (reconnect in %s)", err, backoff)
			select {
			case <-ctx.Done():
				return nil
			case <-time.After(backoff):
			}
			backoff *= 2
			if backoff > maxBackoff {
				backoff = maxBackoff
			}
			continue
		}
		// Clean exit (server closed politely): reset backoff and try again.
		backoff = time.Second
	}
}

// runOnce dials, subscribes, and reads until ctx cancels or an error
// occurs. The initial subscribe also counts as a state change so
// callers seed their view of player state.
func runOnce(ctx context.Context, wsURL string, onChange func()) error {
	cfg, err := websocket.NewConfig(wsURL, "http://localhost/")
	if err != nil {
		return fmt.Errorf("new config: %w", err)
	}
	cfg.Protocol = []string{"notify"}

	ws, err := websocket.DialConfig(cfg)
	if err != nil {
		return fmt.Errorf("dial: %w", err)
	}
	defer ws.Close()

	// Close the conn when the context is cancelled so the blocking
	// Receive returns and the goroutine unwinds.
	doneClosing := make(chan struct{})
	go func() {
		select {
		case <-ctx.Done():
			ws.Close()
		case <-doneClosing:
		}
	}()
	defer close(doneClosing)

	sub := notifyEvent{Notify: []string{"player"}}
	if err := websocket.JSON.Send(ws, sub); err != nil {
		return fmt.Errorf("subscribe: %w", err)
	}

	// Trigger an initial fetch so the consumer reflects current state
	// without waiting for the next event.
	onChange()

	for {
		var ev notifyEvent
		if err := websocket.JSON.Receive(ws, &ev); err != nil {
			if ctx.Err() != nil {
				return nil
			}
			return fmt.Errorf("receive: %w", err)
		}
		if slices.Contains(ev.Notify, "player") {
			onChange()
		}
	}
}

// buildWSURL converts an owntone base URL like "http://host:3689"
// into the notification socket URL "ws://host:<wsPort>/".
func buildWSURL(baseURL string, wsPort int) (string, error) {
	u, err := url.Parse(baseURL)
	if err != nil {
		return "", err
	}
	host := u.Hostname()
	if host == "" {
		return "", fmt.Errorf("base url %q has no host", baseURL)
	}
	scheme := "ws"
	if strings.EqualFold(u.Scheme, "https") {
		scheme = "wss"
	}
	return fmt.Sprintf("%s://%s:%d/", scheme, host, wsPort), nil
}
