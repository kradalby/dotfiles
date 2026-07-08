// Command oci-usage-exporter exposes current-month Oracle Cloud spend as
// Prometheus metrics, one set of gauges per configured account. Always-Free
// tenancies report a null computed amount; anything above zero is real spend.
package main

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/cenkalti/backoff/v5"
	"github.com/knadh/koanf/providers/env"
	"github.com/knadh/koanf/v2"
	"github.com/oracle/oci-go-sdk/v65/common"
	"github.com/oracle/oci-go-sdk/v65/usageapi"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/sync/errgroup"
)

const envPrefix = "OCI_USAGE_"

var ErrNoAccounts = errors.New("no accounts configured, set OCI_USAGE_ACCOUNTS")

type account struct {
	name    string
	tenancy string
	client  usageapi.UsageapiClient
}

type config struct {
	listenAddr string
	interval   time.Duration
	accounts   []account
}

// loadConfig reads OCI_USAGE_* from the environment: ACCOUNTS names a
// comma-separated list, and each account has <NAME>_{TENANCY_OCID, USER_OCID,
// FINGERPRINT, REGION, PRIVATE_KEY_B64}. The key is base64-encoded PEM
// because systemd EnvironmentFile cannot hold multi-line values.
func loadConfig() (*config, error) {
	k := koanf.New(".")
	if err := k.Load(env.Provider(envPrefix, ".", func(s string) string {
		return strings.ToLower(strings.TrimPrefix(s, envPrefix))
	}), nil); err != nil {
		return nil, fmt.Errorf("loading environment: %w", err)
	}

	cfg := &config{
		listenAddr: "localhost:63461",
		interval:   time.Hour,
	}
	if v := k.String("listen_addr"); v != "" {
		cfg.listenAddr = v
	}
	if v := k.String("interval"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			return nil, fmt.Errorf("parsing OCI_USAGE_INTERVAL: %w", err)
		}
		cfg.interval = d
	}

	for name := range strings.SplitSeq(k.String("accounts"), ",") {
		name = strings.TrimSpace(name)
		if name == "" {
			continue
		}
		field := func(f string) string { return k.String(name + "_" + f) }
		keyPEM, err := base64.StdEncoding.DecodeString(field("private_key_b64"))
		if err != nil {
			return nil, fmt.Errorf("account %s: decoding private key: %w", name, err)
		}
		tenancy := field("tenancy_ocid")
		provider := common.NewRawConfigurationProvider(
			tenancy, field("user_ocid"), field("region"), field("fingerprint"), string(keyPEM), nil)
		client, err := usageapi.NewUsageapiClientWithConfigurationProvider(provider)
		if err != nil {
			return nil, fmt.Errorf("account %s: creating usage client: %w", name, err)
		}
		cfg.accounts = append(cfg.accounts, account{name: name, tenancy: tenancy, client: client})
	}
	if len(cfg.accounts) == 0 {
		return nil, ErrNoAccounts
	}
	return cfg, nil
}

type metrics struct {
	registry    *prometheus.Registry
	cost        *prometheus.GaugeVec
	monthTotal  *prometheus.GaugeVec
	up          *prometheus.GaugeVec
	lastSuccess *prometheus.GaugeVec
}

func newMetrics() *metrics {
	registry := prometheus.NewRegistry()
	factory := promauto.With(registry)
	gauge := func(name, help string, labels ...string) *prometheus.GaugeVec {
		return factory.NewGaugeVec(prometheus.GaugeOpts{Name: name, Help: help}, labels)
	}
	return &metrics{
		registry: registry,
		cost: gauge("oci_usage_cost",
			"Current-month cost per service from the OCI Usage API.",
			"account", "service", "currency"),
		monthTotal: gauge("oci_usage_month_total",
			"Current-month total cost; nonzero means spend outside the free tier.",
			"account"),
		up: gauge("oci_usage_up",
			"Whether the last usage query for the account succeeded.",
			"account"),
		lastSuccess: gauge("oci_usage_last_success_seconds",
			"Unix timestamp of the last successful usage query for the account.",
			"account"),
	}
}

// collect queries one account's current-month costs and updates its gauges,
// returning the month total. Failed queries leave the previous values intact.
func (m *metrics) collect(ctx context.Context, acc account) (float64, error) {
	now := time.Now().UTC()
	start := time.Date(now.Year(), now.Month(), 1, 0, 0, 0, 0, time.UTC)
	req := usageapi.RequestSummarizedUsagesRequest{
		RequestSummarizedUsagesDetails: usageapi.RequestSummarizedUsagesDetails{
			TenantId:         common.String(acc.tenancy),
			TimeUsageStarted: &common.SDKTime{Time: start},
			TimeUsageEnded:   &common.SDKTime{Time: start.AddDate(0, 1, 0)},
			Granularity:      usageapi.RequestSummarizedUsagesDetailsGranularityMonthly,
			QueryType:        usageapi.RequestSummarizedUsagesDetailsQueryTypeCost,
			GroupBy:          []string{"service"},
		},
	}

	var items []usageapi.UsageSummary
	for {
		resp, err := backoff.Retry(ctx, func() (usageapi.RequestSummarizedUsagesResponse, error) {
			return acc.client.RequestSummarizedUsages(ctx, req)
		}, backoff.WithMaxTries(3))
		if err != nil {
			return 0, fmt.Errorf("requesting usage: %w", err)
		}
		items = append(items, resp.Items...)
		if resp.OpcNextPage == nil {
			break
		}
		req.Page = resp.OpcNextPage
	}

	type series struct{ service, currency string }
	costs := make(map[series]float64)
	var total float64
	for _, item := range items {
		key := series{
			service:  deref(item.Service),
			currency: strings.TrimSpace(deref(item.Currency)),
		}
		var amount float64
		if item.ComputedAmount != nil {
			amount = float64(*item.ComputedAmount)
		}
		costs[key] += amount
		total += amount
	}

	m.cost.DeletePartialMatch(prometheus.Labels{"account": acc.name})
	for key, amount := range costs {
		m.cost.WithLabelValues(acc.name, key.service, key.currency).Set(amount)
	}
	m.monthTotal.WithLabelValues(acc.name).Set(total)
	m.lastSuccess.WithLabelValues(acc.name).SetToCurrentTime()
	return total, nil
}

func (m *metrics) collectAll(ctx context.Context, logger *slog.Logger, accounts []account) {
	for _, acc := range accounts {
		cctx, cancel := context.WithTimeout(ctx, 2*time.Minute)
		total, err := m.collect(cctx, acc)
		cancel()
		if err != nil {
			m.up.WithLabelValues(acc.name).Set(0)
			logger.Error("collecting usage", "account", acc.name, "err", err)
			continue
		}
		m.up.WithLabelValues(acc.name).Set(1)
		logger.Info("collected usage", "account", acc.name, "month_total", total)
	}
}

func run(logger *slog.Logger) error {
	cfg, err := loadConfig()
	if err != nil {
		return err
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer stop()

	m := newMetrics()

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.HandlerFor(m.registry, promhttp.HandlerOpts{}))
	srv := &http.Server{
		Addr:              cfg.listenAddr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	g, gctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		logger.Info("listening", "addr", cfg.listenAddr, "interval", cfg.interval)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			return fmt.Errorf("serving metrics: %w", err)
		}
		return nil
	})
	g.Go(func() error {
		m.collectAll(gctx, logger, cfg.accounts)
		ticker := time.NewTicker(cfg.interval)
		defer ticker.Stop()
		for {
			select {
			case <-gctx.Done():
				return nil
			case <-ticker.C:
				m.collectAll(gctx, logger, cfg.accounts)
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
		logger.Error("oci-usage-exporter failed", "err", err)
		os.Exit(1)
	}
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}
