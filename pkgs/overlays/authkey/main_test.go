package main

import (
	"testing"

	"github.com/stretchr/testify/require"
)

func TestParseTags(t *testing.T) {
	require.Equal(t, []string{"tag:server", "tag:isolated"}, parseTags(" tag:server, tag:isolated ,"))
	require.Nil(t, parseTags(" , "), "parseTags of empties should be nil")
}

func TestKeyCapabilities(t *testing.T) {
	require.False(t, keyCapabilities(nil, false).Devices.Create.Reusable,
		"default key must be single-use (reusable=false)")
	require.True(t, keyCapabilities(nil, true).Devices.Create.Reusable,
		"-reusable must produce a reusable key")
	c := keyCapabilities([]string{"tag:server"}, false)
	require.True(t, c.Devices.Create.Preauthorized, "key must be preauthorized")
	require.Equal(t, []string{"tag:server"}, c.Devices.Create.Tags)
}

func TestPlatformTable(t *testing.T) {
	require.Len(t, order, len(platforms), "order and platforms must name the same set")
	for _, name := range order {
		p, ok := platforms[name]
		require.True(t, ok, "order names %q which is not in platforms", name)
		require.NotEmpty(t, p.tokenURL, "platform %q tokenURL", name)
		require.NotEmpty(t, p.tailnet, "platform %q tailnet", name)
		require.NotEmpty(t, p.secret, "platform %q secret", name)
		require.NotEmpty(t, p.credID, "platform %q credID", name)
		require.NotEmpty(t, p.credKey, "platform %q credKey", name)
	}
}
