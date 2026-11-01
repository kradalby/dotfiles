// Command energyd keeps a ledger of what energy costs this home. It reads
// NextEnergy's app backend, day-ahead prices, the HomeWizard P1 meter and the
// weather into SQLite, and serves /metrics and a JSON API on localhost.
//
// Configuration is via flags or the matching ENERGYD_-prefixed environment
// variables. Credentials are read only from NEXTENERGY_USERNAME and
// NEXTENERGY_PASSWORD.
package main

import (
	"context"
	"errors"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/peterbourgon/ff/v4"
	"github.com/peterbourgon/ff/v4/ffhelp"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promhttp"
	"golang.org/x/sync/errgroup"

	"energyd/api"
	"energyd/collect"
	"energyd/db"
	"energyd/ledger"
	"energyd/nextenergy"
	"energyd/tz"
)

const (
	meterInterval    = time.Minute
	priceTick        = 15 * time.Minute
	priceInterval    = time.Hour
	supplierTick     = time.Hour
	supplierInterval = 6 * time.Hour
	// Hourly, because each past hour keeps the last forecast made for it.
	weatherInterval = time.Hour
	metricsInterval = time.Minute
	httpTimeout     = 20 * time.Second

	// Day-ahead prices appear around 13:00 local.
	pricesPublishedHour = 13
	// backfillPriceStep fits one reply: each spans the day before to the day after.
	backfillPriceStep = 3
	backfillPriceGap  = time.Second
)

func main() { os.Exit(run()) }

func run() int {
	ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
	defer cancel()

	log := slog.New(slog.NewTextHandler(os.Stdout, nil))

	root := newRootCommand(log)

	err := root.ParseAndRun(ctx, os.Args[1:], ff.WithEnvVarPrefix("ENERGYD"))
	if err != nil {
		if errors.Is(err, ff.ErrHelp) {
			fmt.Fprintln(os.Stderr, ffhelp.Command(root))

			return 0
		}

		log.Error("energyd failed", "err", err)

		return 1
	}

	return 0
}

type config struct {
	dbPath     *string
	listenAddr *string
	meter      *string
	latitude   *float64
	longitude  *float64
}

func newRootCommand(log *slog.Logger) *ff.Command {
	fs := ff.NewFlagSet("energyd")
	cfg := &config{
		dbPath:     fs.StringLong("db-path", "energyd.db", "SQLite database path"),
		listenAddr: fs.StringLong("listen-addr", "127.0.0.1:63463", "address for /metrics and /api"),
		meter:      fs.StringLong("meter", "power-p1-meter.ldn.fap.no", "HomeWizard P1 meter host"),
		latitude:   fs.Float64Long("latitude", 52.16, "latitude for weather; the city, not the house"),
		longitude:  fs.Float64Long("longitude", 4.49, "longitude for weather; the city, not the house"),
	}

	backfillFlags := ff.NewFlagSet("backfill").SetParent(fs)
	from := backfillFlags.StringLong("from", "", "first local day to read (default: contract start)")
	unblockFlags := ff.NewFlagSet("unblock").SetParent(fs)

	return &ff.Command{
		Name:  "energyd",
		Usage: "energyd [FLAGS] [SUBCOMMAND]",
		Flags: fs,
		Exec: func(ctx context.Context, _ []string) error {
			return serve(ctx, log, cfg)
		},
		Subcommands: []*ff.Command{{
			Name:      "backfill",
			Usage:     "energyd backfill [--from YYYY-MM-DD]",
			ShortHelp: "read history from NextEnergy, resumable by missing days",
			Flags:     backfillFlags,
			Exec: func(ctx context.Context, _ []string) error {
				return backfill(ctx, log, cfg, *from)
			},
		}, {
			Name:      "unblock",
			Usage:     "energyd unblock",
			ShortHelp: "clear the login block after fixing the credentials",
			Flags:     unblockFlags,
			Exec: func(ctx context.Context, _ []string) error {
				return unblock(ctx, cfg)
			},
		}},
	}
}

var errNoCredentials = errors.New("NEXTENERGY_USERNAME and NEXTENERGY_PASSWORD are required")

func newClient() (*nextenergy.Client, error) {
	user, password := os.Getenv("NEXTENERGY_USERNAME"), os.Getenv("NEXTENERGY_PASSWORD")
	if user == "" || password == "" {
		return nil, errNoCredentials
	}

	return nextenergy.New(user, password)
}

func serve(ctx context.Context, log *slog.Logger, cfg *config) error {
	store, err := db.Open(ctx, *cfg.dbPath)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer func() { _ = store.Close() }()

	// Meter, prices and weather need no login, so a missing one stops only the
	// supplier. EnergydSupplierNeverRead reports it.
	client, err := newClient()
	switch {
	case errors.Is(err, errNoCredentials):
		log.Warn("no NextEnergy credentials, supplier disabled")

		client = nil
	case err != nil:
		return err
	default:
		if err := client.UseLoginStore(ctx, store); err != nil {
			return err
		}
	}

	m := newMetrics(prometheus.DefaultRegisterer)
	httpClient := &http.Client{Timeout: httpTimeout}
	led := ledger.New(store)

	svc := &service{
		log:     log,
		metrics: m,
		ledger:  led,
		client:  client,
		meter:   &collect.Meter{DB: store, HTTP: httpClient, Target: *cfg.meter},
		prices:  collect.NewPrices(store, httpClient),
		weather: collect.NewWeather(store, httpClient, *cfg.latitude, *cfg.longitude),
	}

	if client != nil {
		svc.supplier = &collect.Supplier{DB: store, Client: client}
	}

	mux := http.NewServeMux()
	mux.Handle("/metrics", promhttp.Handler())
	mux.HandleFunc("/healthz", func(w http.ResponseWriter, _ *http.Request) { fmt.Fprintln(w, "ok") })
	api.New(led, store).Register(mux)

	srv := &http.Server{Addr: *cfg.listenAddr, Handler: mux, ReadHeaderTimeout: 10 * time.Second}

	g, ctx := errgroup.WithContext(ctx)
	g.Go(func() error {
		err := srv.ListenAndServe()
		if errors.Is(err, http.ErrServerClosed) {
			return nil
		}

		return fmt.Errorf("http: %w", err)
	})
	g.Go(func() error {
		<-ctx.Done()

		shutdown, cancel := context.WithTimeout(context.Background(), 10*time.Second)
		defer cancel()

		return srv.Shutdown(shutdown)
	})
	g.Go(func() error { return every(ctx, meterInterval, svc.pollMeter) })
	g.Go(func() error { return every(ctx, priceTick, svc.pollPrices) })
	g.Go(func() error { return every(ctx, supplierTick, svc.pollSupplier) })
	g.Go(func() error { return every(ctx, weatherInterval, svc.pollWeather) })
	g.Go(func() error { return every(ctx, metricsInterval, svc.refreshMetrics) })

	return g.Wait()
}

// every runs fn now and then on each tick. One source failing never stops the
// others; the next tick is the retry.
func every(ctx context.Context, interval time.Duration, fn func(context.Context)) error {
	fn(ctx)

	t := time.NewTicker(interval)
	defer t.Stop()

	for {
		select {
		case <-ctx.Done():
			return nil
		case <-t.C:
			fn(ctx)
		}
	}
}

type service struct {
	log      *slog.Logger
	metrics  *metrics
	ledger   *ledger.Ledger
	client   *nextenergy.Client
	meter    *collect.Meter
	prices   *collect.Prices
	weather  *collect.Weather
	supplier *collect.Supplier

	lastPriceFetch      time.Time
	lastSupplierSuccess time.Time
}

func (s *service) record(source string, err error) {
	if err != nil {
		s.metrics.sourceFailure(source)
		s.log.Error("read failed", "source", source, "err", err)

		return
	}

	s.metrics.sourceSuccess(source, time.Now())
}

func (s *service) pollMeter(ctx context.Context) {
	s.record("meter", s.meter.Poll(ctx, time.Now()))
}

// priceFetchDue limits the public feed to hourly, except while tomorrow's prices
// should be out and are not. Those are the only minutes polling faster helps.
func priceFetchDue(now, last time.Time, haveTomorrow bool) bool {
	if now.Sub(last) >= priceInterval {
		return true
	}

	return !haveTomorrow && now.In(tz.Amsterdam).Hour() >= pricesPublishedHour
}

func (s *service) pollPrices(ctx context.Context) {
	snapshot, err := s.ledger.Snapshot(ctx)
	if err != nil {
		s.log.Error("snapshot failed", "err", err)
	}

	now := time.Now()
	if !priceFetchDue(now, s.lastPriceFetch, snapshot.TomorrowHours > 0) {
		return
	}

	s.lastPriceFetch = now
	s.record("prices", s.prices.Fetch(ctx, now))
}

// supplierPollDue rests six hours after a good read, because the data is a day
// late anyway, and retries every tick after a bad one.
func supplierPollDue(now, lastSuccess time.Time) bool {
	return now.Sub(lastSuccess) >= supplierInterval
}

func (s *service) pollSupplier(ctx context.Context) {
	now := time.Now()
	if s.client == nil || !supplierPollDue(now, s.lastSupplierSuccess) {
		return
	}

	contract, err := s.client.Contract(ctx)
	if err == nil {
		err = s.supplier.Recent(ctx, now, contract.HasGas)
	}

	if err == nil {
		err = s.supplier.Account(ctx, now)
	}

	s.record("nextenergy", err)

	if err == nil {
		s.lastSupplierSuccess = now
	} else {
		// The session may have gone bad in a way nobody has seen yet, so the next
		// poll starts fresh. Login spacing and the block still apply.
		s.client.Reset()
	}

	s.refreshMetrics(ctx)
}

func (s *service) pollWeather(ctx context.Context) {
	s.record("weather", s.weather.Poll(ctx, time.Now()))
}

func (s *service) refreshMetrics(ctx context.Context) {
	snapshot, err := s.ledger.Snapshot(ctx)
	if err != nil {
		s.log.Error("snapshot failed", "err", err)

		return
	}

	var state sourceState
	if s.client != nil {
		state = sourceState{
			loginBlocked:      s.client.LoginBlocked(),
			apiVersionChanged: s.client.APIVersionChanged(),
			logins:            s.client.Logins(),
		}
	}

	s.metrics.update(snapshot, state)
}

// backfill reads history once. It stops at the first NextEnergy failure, because
// a broken session must not run on against a real account. Prices are best
// effort: a day without one keeps NextEnergy's totals and has no computed hours.
func backfill(ctx context.Context, log *slog.Logger, cfg *config, fromDay string) error {
	client, err := newClient()
	if err != nil {
		return err
	}

	store, err := db.Open(ctx, *cfg.dbPath)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer func() { _ = store.Close() }()

	if err := client.UseLoginStore(ctx, store); err != nil {
		return err
	}

	if err := client.WaitForLogin(ctx); err != nil {
		return err
	}

	httpClient := &http.Client{Timeout: httpTimeout}
	today := tz.Day(time.Now())
	supplier := &collect.Supplier{DB: store, Client: client}

	if err := supplier.Account(ctx, today); err != nil {
		return err
	}

	from, err := backfillStart(ctx, store, fromDay)
	if err != nil {
		return err
	}

	weather := collect.NewWeather(store, httpClient, *cfg.latitude, *cfg.longitude)
	if err := weather.Archive(ctx, from, today.AddDate(0, 0, -2)); err != nil {
		log.Warn("weather archive failed", "err", err)
	}

	err = supplier.Backfill(ctx, from, today, func(day time.Time) {
		if day.Day() == 1 {
			log.Info("backfill reached", "day", tz.DateString(day))
		}
	})
	if err != nil {
		return err
	}

	prices := collect.NewPrices(store, httpClient)

	for d := from; d.Before(today); d = d.AddDate(0, 0, backfillPriceStep) {
		if err := prices.Fetch(ctx, d); err != nil {
			log.Warn("prices unavailable", "day", tz.DateString(d), "err", err)
		}

		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(backfillPriceGap):
		}
	}

	log.Info("backfill done")

	return nil
}

func backfillStart(ctx context.Context, store *db.DB, fromDay string) (time.Time, error) {
	if fromDay == "" {
		return ledger.New(store).ContractStart(ctx)
	}

	from, err := tz.ParseDate(fromDay)
	if err != nil {
		return time.Time{}, fmt.Errorf("--from: %w", err)
	}

	return from, nil
}

// unblock clears a login block after the credentials were fixed. The last attempt
// stays, so spacing still applies. Restart the service afterwards.
func unblock(ctx context.Context, cfg *config) error {
	store, err := db.Open(ctx, *cfg.dbPath)
	if err != nil {
		return fmt.Errorf("open db: %w", err)
	}
	defer func() { _ = store.Close() }()

	last, _, err := store.LoadLogin(ctx)
	if err != nil {
		return err
	}

	return store.SaveLogin(ctx, last, time.Time{})
}
