package owntone

import (
	"context"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
	"golang.org/x/net/websocket"
)

func TestWebSocketHandshakeCancellation(t *testing.T) {
	started := make(chan struct{})
	release := make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		close(started)
		<-release
	}))
	t.Cleanup(upstream.Close)
	t.Cleanup(func() { close(release) })
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()
	done := make(chan error, 1)
	go func() { done <- runOnce(ctx, "ws"+upstream.URL[4:]+"/", func() {}) }()
	select {
	case <-started:
	case <-time.After(time.Second):
		t.Fatal("handshake did not reach the server")
	}
	cancel()
	select {
	case err := <-done:
		var dialErr *websocket.DialError
		require.ErrorAs(t, err, &dialErr)
		require.ErrorIs(t, dialErr.Err, context.Canceled)
	case <-time.After(time.Second):
		t.Fatal("handshake ignored cancellation")
	}
}

func TestWebSocketHandshakeDeadline(t *testing.T) {
	release := make(chan struct{})
	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		<-release
	}))
	t.Cleanup(upstream.Close)
	t.Cleanup(func() { close(release) })
	done := make(chan error, 1)
	go func() { done <- runOnce(context.Background(), "ws"+upstream.URL[4:]+"/", func() {}) }()
	select {
	case err := <-done:
		var dialErr *websocket.DialError
		require.ErrorAs(t, err, &dialErr)
		require.ErrorIs(t, dialErr.Err, context.DeadlineExceeded)
	case <-time.After(12 * time.Second):
		t.Fatal("handshake exceeded its deadline")
	}
}
