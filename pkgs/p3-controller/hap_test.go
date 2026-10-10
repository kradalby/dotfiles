package main

import (
	"context"
	"net"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/stretchr/testify/require"

	"p3-controller/owntone"
)

func TestRunHAPReturnsStartupError(t *testing.T) {
	occupied, err := net.Listen("tcp", "127.0.0.1:0")
	require.NoError(t, err)
	t.Cleanup(func() { require.NoError(t, occupied.Close()) })

	upstream := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		_, err := w.Write([]byte(`{"websocket_port":0}`))
		require.NoError(t, err)
	}))
	t.Cleanup(upstream.Close)
	ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
	defer cancel()

	err = runHAP(ctx, owntone.NewClient(upstream.URL), &Config{HAP: HAPConfig{
		Pin:      "31415926",
		Port:     occupied.Addr().(*net.TCPAddr).Port,
		StateDir: t.TempDir(),
	}})
	var bindErr *net.OpError
	require.ErrorAs(t, err, &bindErr)
	require.Equal(t, "listen", bindErr.Op)
	require.NoError(t, ctx.Err(), "worker teardown must not depend on parent cancellation")
}
