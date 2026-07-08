package main

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/base64"
	"encoding/pem"
	"testing"
	"time"

	"github.com/stretchr/testify/require"
)

func TestLoadConfig(t *testing.T) {
	key, err := rsa.GenerateKey(rand.Reader, 2048)
	require.NoError(t, err)
	keyPEM := pem.EncodeToMemory(&pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(key),
	})
	keyB64 := base64.StdEncoding.EncodeToString(keyPEM)

	t.Setenv("OCI_USAGE_ACCOUNTS", "kradalby, vsdalby")
	t.Setenv("OCI_USAGE_INTERVAL", "30m")
	for _, name := range []string{"KRADALBY", "VSDALBY"} {
		t.Setenv("OCI_USAGE_"+name+"_TENANCY_OCID", "ocid1.tenancy.oc1..test"+name)
		t.Setenv("OCI_USAGE_"+name+"_USER_OCID", "ocid1.user.oc1..test")
		t.Setenv("OCI_USAGE_"+name+"_FINGERPRINT", "aa:bb:cc")
		t.Setenv("OCI_USAGE_"+name+"_REGION", "uk-london-1")
		t.Setenv("OCI_USAGE_"+name+"_PRIVATE_KEY_B64", keyB64)
	}

	cfg, err := loadConfig()
	require.NoError(t, err)
	require.Equal(t, "localhost:63461", cfg.listenAddr)
	require.Equal(t, 30*time.Minute, cfg.interval)
	require.Len(t, cfg.accounts, 2)
	require.Equal(t, "kradalby", cfg.accounts[0].name)
	require.Equal(t, "ocid1.tenancy.oc1..testKRADALBY", cfg.accounts[0].tenancy)
}

func TestLoadConfigNoAccounts(t *testing.T) {
	t.Setenv("OCI_USAGE_ACCOUNTS", "")
	_, err := loadConfig()
	require.ErrorIs(t, err, ErrNoAccounts)
}
