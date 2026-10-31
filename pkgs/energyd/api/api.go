// Package api serves the ledger as JSON for Grafana's Infinity datasource. It
// listens on localhost only. Bills are served here and never reach Prometheus,
// which Grafana MCP exposes across the tailnet.
package api

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	"energyd/db"
	"energyd/ledger"
)

const (
	// farPast starts default ranges before any stored data.
	farPast = 946684800 // 2000-01-01

	weekdayHoursDays = 90
)

// Server answers the JSON API.
type Server struct {
	ledger *ledger.Ledger
	db     *db.DB
	now    func() time.Time
}

// New builds a server.
func New(l *ledger.Ledger, d *db.DB) *Server { return &Server{ledger: l, db: d, now: time.Now} }

// Register adds every endpoint to mux.
func (s *Server) Register(mux *http.ServeMux) {
	mux.HandleFunc("/api/hours", s.ranged(func(r *http.Request, from, to time.Time) (any, error) {
		return s.ledger.Hours(r.Context(), from, to)
	}))
	mux.HandleFunc("/api/bands", s.ranged(func(r *http.Request, from, to time.Time) (any, error) {
		return s.ledger.Bands(r.Context(), from, to)
	}))
	mux.HandleFunc("/api/days", s.ranged(func(r *http.Request, from, to time.Time) (any, error) {
		return s.ledger.Days(r.Context(), from, to)
	}))
	mux.HandleFunc("/api/months", s.ranged(func(r *http.Request, from, to time.Time) (any, error) {
		return s.ledger.Months(r.Context(), from, to)
	}))
	mux.HandleFunc("/api/degreedays", s.ranged(func(r *http.Request, from, to time.Time) (any, error) {
		period := r.URL.Query().Get("period")
		if period == "" {
			period = "month"
		}

		return s.ledger.DegreeDays(r.Context(), from, to, period)
	}))
	mux.HandleFunc("/api/weekdayhours", s.ranged(func(r *http.Request, from, to time.Time) (any, error) {
		// Habits drift, so the default looks at one recent season, not all history.
		if r.URL.Query().Get("from") == "" {
			from = to.AddDate(0, 0, -weekdayHoursDays)
		}

		return s.ledger.WeekdayHours(r.Context(), from, to)
	}))
	mux.HandleFunc("/api/years", s.ranged(func(r *http.Request, _, _ time.Time) (any, error) {
		return s.ledger.ContractYears(r.Context())
	}))
	mux.HandleFunc("/api/estimate", s.ranged(func(r *http.Request, _, _ time.Time) (any, error) {
		return s.ledger.Estimate(r.Context())
	}))
	mux.HandleFunc("/api/bills", s.ranged(func(r *http.Request, _, _ time.Time) (any, error) {
		return s.bills(r)
	}))
}

// ranged reads from and to, then writes what fn returns. A nil slice would encode
// as null, which Infinity reports as an error rather than as no data.
func (s *Server) ranged(fn func(r *http.Request, from, to time.Time) (any, error)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		q := r.URL.Query()
		from := time.Unix(parseTime(q.Get("from"), farPast), 0)
		to := time.Unix(parseTime(q.Get("to"), s.now().AddDate(0, 0, 2).Unix()), 0)

		// Grafana reduces a legend over all rows returned, so a panel asks for no
		// more than it shows. Panel time overrides do not reach the URL.
		if days, err := strconv.Atoi(q.Get("days")); err == nil && days > 0 {
			from = s.now().AddDate(0, 0, -days)
		}

		out, err := fn(r, from, to)
		if err != nil {
			http.Error(w, "query failed", http.StatusInternalServerError)

			return
		}

		w.Header().Set("Content-Type", "application/json")

		raw, err := json.Marshal(out)
		if err != nil || string(raw) == "null" {
			raw = []byte("[]")
		}

		_, _ = w.Write(raw)
	}
}

type bill struct {
	Kind        string  `json:"kind"`
	PeriodStart string  `json:"period_start"`
	PeriodEnd   string  `json:"period_end"`
	Due         string  `json:"due"`
	AmountEUR   float64 `json:"amount_eur"`
	Paid        bool    `json:"paid"`
	Credited    bool    `json:"credited"`
}

func (s *Server) bills(r *http.Request) ([]bill, error) {
	rows, err := s.db.ListBills(r.Context())
	if err != nil {
		return nil, err
	}

	out := make([]bill, 0, len(rows))
	for _, b := range rows {
		out = append(out, bill{
			Kind: b.Kind, PeriodStart: b.PeriodStart, PeriodEnd: b.PeriodEnd, Due: b.Due,
			AmountEUR: b.AmountEur, Paid: b.Paid != 0, Credited: b.Credited != 0,
		})
	}

	return out, nil
}

// parseTime reads a unix timestamp, tolerating Grafana's millisecond epochs.
func parseTime(s string, def int64) int64 {
	v, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return def
	}

	if v > 1_000_000_000_000 {
		v /= 1000
	}

	return v
}
