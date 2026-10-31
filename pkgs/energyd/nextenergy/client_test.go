package nextenergy

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"energyd/tz"

	"github.com/stretchr/testify/require"
)

const (
	syncReply = `{"data":{"IsSuccess":true,
		"SyncContractData":{"ContractId":"4242","StartDate":"2022-09-10","DeliveryCity":"PRIVATE"},
		"SyncContractlineIntervals":{"HasElectricity":true,"HasGas":true},
		"SyncAccountData":{"Email":"private@example.com"}}}`
	screenReply = `{"data":{"Out_ScreenVariables":{"HasGas":true},"Out_ContractInfo":{"ContractNumber":"PRIVATE"},"Out_ContractProposition":{}}}`
	usageReply  = `{"data":{"DayStatusId":"","Out_IsSmartMeter":true,
		"TotalsPerPeriod":{"TotalElecEuro":"3.1","TotalGasEuro":"1.76",
			"Elec":{"DeliveryVolume":"9.5","DeliveryCosts":"2.25","ReturnVolume":"0.0","ReturnCosts":"0.0","EnergyTax":"1.05","FixedCosts":"-0.2"},
			"Gas":{"DeliveryVolume":"0.5","DeliveryCosts":"0.6","ReturnVolume":"0.0","ReturnCosts":"0.0","EnergyTax":"0.36","FixedCosts":"0.8"}},
		"DataPoints":{"List":[@POINTS@]}}}`
	feeReply = `{"data":{"OutContractProposition":{
		"Electricity":{"Price":"0.02","StartDateTariff":"2022-09-10","EndDateTariff":"1900-01-01"},
		"Gas":{"Price":"0.11","StartDateTariff":"2022-09-10","EndDateTariff":"1900-01-01"}}}}`
	invoiceReply = `{"data":{"Str_Out_Invoice_V3":{"List":[
		{"ContractId":"4242","InvoiceId":"1","InvoiceNumber":"PRIVATE",
		 "Period":{"StartDate":"2026-11-01","EndDate":"2026-12-01"},"DueDate":"2026-10-26","IsCredited":false,"IsPaid":true,
		 "Str_Out_InvoiceType":{"InvoiceTypeLabel":"Termijnnota"},"TotalAmountIncludingVAT":"150.00000000"},
		{"Period":{"StartDate":"2025-09-10","EndDate":"2026-09-10"},"DueDate":"2026-10-01","IsCredited":false,"IsPaid":true,
		 "Str_Out_InvoiceType":{"InvoiceTypeLabel":"Jaarnota"},"TotalAmountIncludingVAT":"-300.50000000"}]}}}`
)

// backend fakes the app backend. Handlers are keyed by action name, the last
// path segment, and stay swappable so a test can change a reply mid-run.
type backend struct {
	mu      sync.Mutex
	replies map[string]string
	bodies  map[string][]string
	headers map[string][]string
	logins  int
	cookies []string
	status  map[string]int
	srv     *httptest.Server
}

// points builds a day of hourly points for one series.
func points(series string, labels ...string) string {
	out := make([]string, 0, len(labels))
	for _, l := range labels {
		out = append(out, fmt.Sprintf(`{"Label":%q,"Value":"1.00","SeriesName":%q}`, l, series))
	}

	return strings.Join(out, ",")
}

func dayLabels() []string {
	out := make([]string, 0, 24)
	for h := range 24 {
		out = append(out, fmt.Sprintf("%02d:00:00", h))
	}

	return out
}

func usageOf(series string) string {
	return strings.Replace(usageReply, "@POINTS@", points(series, dayLabels()...)+`,`+points("Teruglevering", "01:00:00"), 1)
}

func newBackend(t *testing.T) *backend {
	t.Helper()

	b := &backend{
		replies: map[string]string{
			"ActionDoLogin":                         `{"data":{"HasSeenBiometricInfo":false,"OneSignalAppId":"x"}}`,
			"ActionGetContractAndAccountDataToSync": syncReply,
			"ActionUsage_GetData":                   screenReply,
			"DataActionGetUsageData":                usageOf("Stroom"),
			"DataActionGetPropositionData":          feeReply,
			"DataActionGetInvoicesByUserId_API":     invoiceReply,
		},
		bodies:  map[string][]string{},
		headers: map[string][]string{},
		status:  map[string]int{},
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/Mobile_EnergyNext/Login", func(http.ResponseWriter, *http.Request) {})
	mux.HandleFunc("/Mobile_EnergyNext/moduleservices/moduleversioninfo", func(w http.ResponseWriter, _ *http.Request) {
		fmt.Fprint(w, `{"versionToken":"module-1"}`)
	})
	mux.HandleFunc("/Mobile_EnergyNext/screenservices/", func(w http.ResponseWriter, r *http.Request) {
		name := r.URL.Path[strings.LastIndex(r.URL.Path, "/")+1:]
		body, _ := io.ReadAll(r.Body)

		b.mu.Lock()
		defer b.mu.Unlock()

		b.bodies[name] = append(b.bodies[name], string(body))
		b.headers[name] = append(b.headers[name], r.Header.Get("X-CSRFToken"))

		if code := b.status[name]; code != 0 {
			if name == "ActionDoLogin" {
				b.logins++
			}
			http.Error(w, "refused", code)

			return
		}

		if name == "ActionDoLogin" {
			b.logins++
			b.cookies = append(b.cookies, r.Header.Get("Cookie"))
			cookie := "uid%3D1%3Bcrf%3Dtoken-1%3Bexp%3D2"
			if c, ok := b.replies["loginCookie"]; ok {
				cookie = c
			}
			if cookie != "" {
				http.SetCookie(w, &http.Cookie{Name: sessionCookie, Value: cookie, Path: "/"})
			}
		}

		fmt.Fprint(w, b.replies[name])
	})

	b.srv = httptest.NewServer(mux)
	t.Cleanup(b.srv.Close)

	return b
}

func (b *backend) set(action, reply string) {
	b.mu.Lock()
	defer b.mu.Unlock()
	b.replies[action] = reply
}

func (b *backend) client(t *testing.T) *Client {
	t.Helper()

	c, err := New("user@example.com", "secret-password")
	require.NoError(t, err)

	c.baseURL = b.srv.URL + "/Mobile_EnergyNext"
	c.minGap = 0

	return c
}

func day(t *testing.T, s string) time.Time {
	t.Helper()

	d, err := tz.ParseDate(s)
	require.NoError(t, err)

	return d
}

// The backend answers "Invalid Login" to valid credentials when the header is
// absent, and needs the cookie's crf value afterwards.
func TestLoginSendsEmptyCSRFThenCookieValue(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.NoError(t, err)

	require.Equal(t, []string{""}, b.headers["ActionDoLogin"])
	require.Equal(t, []string{"token-1"}, b.headers["ActionGetContractAndAccountDataToSync"])

	var sent struct {
		VersionInfo struct{ ModuleVersion, APIVersion string }
		ViewName    string
	}
	require.NoError(t, json.Unmarshal([]byte(b.bodies["ActionDoLogin"][0]), &sent))
	require.Equal(t, "module-1", sent.VersionInfo.ModuleVersion)
	require.Equal(t, "6RXNTWQg6FlgienWK8L57A", sent.VersionInfo.APIVersion)
	require.Equal(t, "EntryFlow.Login_New", sent.ViewName)
}

// A wrong password retried on a timer can lock the account, so one rejection
// must stop every later attempt without touching the backend.
func TestRejectedPasswordBlocksFurtherLogins(t *testing.T) {
	b := newBackend(t)
	b.set("ActionDoLogin", `{"exception":{"name":"ServerException","message":"Invalid Login"}}`)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginRejected)
	require.True(t, c.LoginBlocked())

	_, err = c.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginRejected)
	require.Equal(t, 1, b.logins)
	require.Equal(t, 1, c.Logins())
}

func TestLoginBlockExpires(t *testing.T) {
	b := newBackend(t)
	b.set("ActionDoLogin", `{"exception":{"message":"Invalid Login"}}`)
	c := b.client(t)

	now := time.Date(2026, 10, 31, 8, 0, 0, 0, time.UTC)
	c.now = func() time.Time { return now }

	_, err := c.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginRejected)

	now = now.Add(loginBlock + time.Minute)
	b.set("ActionDoLogin", `{"data":{}}`)

	_, err = c.Contract(t.Context())
	require.NoError(t, err)
	require.False(t, c.LoginBlocked())
}

func TestExpiredSessionLogsInOnceAndRetries(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.NoError(t, err)
	c.contract = nil

	expired := `{"exception":{"name":"NotRegistered","message":"not logged in"}}`
	b.set("ActionGetContractAndAccountDataToSync", expired)
	// Past the login spacing, so this session may log in again.
	c.lastLogin = time.Now().Add(-2 * loginSpacing)

	_, err = c.Contract(t.Context())
	require.Error(t, err, "still expired after one fresh login")
	require.Equal(t, 2, b.logins, "exactly one new login, no loop")
}

func TestExpiredSessionDoesNotLoginAgainWithinSpacing(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.NoError(t, err)
	c.contract = nil

	b.set("ActionGetContractAndAccountDataToSync", `{"exception":{"name":"NotRegistered","message":"x"}}`)

	_, err = c.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginSpacing)
	require.Equal(t, 1, b.logins)
}

// A stale apiVersion answers HTTP 200 with empty data and no exception, so the
// flag is the only sign anything is wrong.
func TestAPIVersionFlagIsAnError(t *testing.T) {
	b := newBackend(t)
	b.set("ActionGetContractAndAccountDataToSync", `{"versionInfo":{"hasApiVersionChanged":true},"data":{}}`)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.ErrorIs(t, err, ErrAPIVersionChanged)
	require.True(t, c.APIVersionChanged())
}

func TestContractReadsOnlyNeededFields(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	got, err := c.Contract(t.Context())
	require.NoError(t, err)
	require.Equal(t, int64(4242), got.ID)
	require.True(t, got.HasGas)
	require.NotContains(t, fmt.Sprintf("%+v", got), "PRIVATE")
	require.NotContains(t, fmt.Sprintf("%+v", got), "private@example.com")
}

func TestUsageParsesTotalsAndScalesHours(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	got, err := c.Usage(t.Context(), day(t, "2026-10-27"), Electricity)
	require.NoError(t, err)
	require.False(t, got.Missing())
	require.InDelta(t, 9.5, got.Elec.Volume, 1e-9)
	require.InDelta(t, 2.25, got.Elec.Delivery, 1e-9)
	require.InDelta(t, 1.05, got.Elec.Tax, 1e-9)
	require.InDelta(t, -0.2, got.Elec.Fixed, 1e-9)
	require.InDelta(t, 0.5, got.Gas.Volume, 1e-9)
	require.InDelta(t, 3.1, got.TotalElec, 1e-9)
	require.InDelta(t, 1.76, got.TotalGas, 1e-9)

	require.Len(t, got.Hours, 24, "other series must not count as delivery")
	require.InDelta(t, 9.5/24, got.Hours[0].Volume, 1e-9, "rounded points scale to the exact day total")
	require.Equal(t, day(t, "2026-10-27"), got.Hours[0].Start.In(tz.Amsterdam))

	require.Contains(t, b.bodies["DataActionGetUsageData"][0], `"UsageUtilityTypeId":2`)
	require.Contains(t, b.bodies["DataActionGetUsageData"][0], `"In_ContractId":4242`)
	require.Contains(t, b.bodies["DataActionGetUsageData"][0], `"In_DateTime":"2026-10-27T00:00:00Z"`)
}

func TestUsageGasUsesGasSeries(t *testing.T) {
	b := newBackend(t)
	b.set("DataActionGetUsageData", usageOf("Gas"))
	c := b.client(t)

	got, err := c.Usage(t.Context(), day(t, "2026-10-27"), Gas)
	require.NoError(t, err)
	require.Len(t, got.Hours, 24)
	require.InDelta(t, 0.5/24, got.Hours[1].Volume, 1e-9)
	require.Contains(t, b.bodies["DataActionGetUsageData"][0], `"UsageUtilityTypeId":1`)
}

func TestUsageMissingDayIsNotAnError(t *testing.T) {
	b := newBackend(t)
	b.set("DataActionGetUsageData", `{"data":{"DayStatusId":"MISS","TotalsPerPeriod":{},"DataPoints":{"List":[]}}}`)
	c := b.client(t)

	got, err := c.Usage(t.Context(), day(t, "2026-10-30"), Electricity)
	require.NoError(t, err)
	require.True(t, got.Missing())
}

func TestUsageEmptyPointsWithoutMissIsAnError(t *testing.T) {
	b := newBackend(t)
	b.set("DataActionGetUsageData", `{"data":{"DayStatusId":"","TotalsPerPeriod":{"Elec":{"DeliveryVolume":"9.5"}},"DataPoints":{"List":[]}}}`)
	c := b.client(t)

	_, err := c.Usage(t.Context(), day(t, "2026-10-27"), Electricity)
	require.ErrorIs(t, err, ErrEmptyReply)
}

// A reply can succeed and say nothing. Accepted, it would overwrite good days
// with zeros while every health signal stays green.
func TestUsageDeliveredDayMustCarryData(t *testing.T) {
	for _, tt := range []struct{ name, reply string }{
		{"renamed series", usageOf("Electricity")},
		{"no totals", strings.ReplaceAll(usageOf("Stroom"), `"DeliveryVolume":"9.5"`, `"DeliveryVolume":"0"`)},
		{"labels no longer parse", strings.ReplaceAll(usageOf("Stroom"), ":00:00", "h")},
	} {
		t.Run(tt.name, func(t *testing.T) {
			b := newBackend(t)
			b.set("DataActionGetUsageData", tt.reply)
			c := b.client(t)

			_, err := c.Usage(t.Context(), day(t, "2026-10-27"), Electricity)
			require.ErrorIs(t, err, ErrEmptyReply)
		})
	}
}

// On the short and long days a label can name a skipped or repeated local hour.
// Volume must survive either way, summed onto the instant Go resolves it to.
func TestUsageDSTLabelsKeepEveryVolume(t *testing.T) {
	short := make([]string, 0, 23)
	for _, l := range dayLabels() {
		if l != "02:00:00" {
			short = append(short, l)
		}
	}

	for _, tt := range []struct {
		name, date string
		labels     []string
	}{
		{"spring gap", "2026-03-29", short},
		{"spring label kept", "2026-03-29", dayLabels()},
		{"autumn repeat", "2026-10-25", append(dayLabels(), "02:00:00")},
	} {
		t.Run(tt.name, func(t *testing.T) {
			b := newBackend(t)
			b.set("DataActionGetUsageData", fmt.Sprintf(`{"data":{"DayStatusId":"","TotalsPerPeriod":{"Elec":{"DeliveryVolume":"%d.0"}},"DataPoints":{"List":[%s]}}}`,
				len(tt.labels), points("Stroom", tt.labels...)))
			c := b.client(t)

			got, err := c.Usage(t.Context(), day(t, tt.date), Electricity)
			require.NoError(t, err)

			var sum float64
			for _, h := range got.Hours {
				sum += h.Volume
			}
			require.InDelta(t, float64(len(tt.labels)), sum, 1e-9)
		})
	}
}

func TestFees(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	got, err := c.Fees(t.Context(), day(t, "2026-10-27"))
	require.NoError(t, err)
	require.Equal(t, []Fee{
		{Utility: Electricity, EURExVAT: 0.02, ValidFrom: "2022-09-10"},
		{Utility: Gas, EURExVAT: 0.11, ValidFrom: "2022-09-10"},
	}, got)
	require.Contains(t, b.headersFor("DataActionGetPropositionData"), "token-1")
	require.Contains(t, b.bodies["DataActionGetPropositionData"][0], `"viewName":"MainFlow.MarketPrices"`)
}

func (b *backend) headersFor(action string) []string { return b.headers[action] }

func TestFeesZeroPriceIsAnError(t *testing.T) {
	b := newBackend(t)
	b.set("DataActionGetPropositionData", `{"data":{"OutContractProposition":{"Electricity":{"Price":"0.0"},"Gas":{"Price":"0.0"}}}}`)
	c := b.client(t)

	_, err := c.Fees(t.Context(), day(t, "2026-10-27"))
	require.ErrorIs(t, err, ErrEmptyReply)
}

func TestInvoicesCarryNoInvoiceNumber(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	got, err := c.Invoices(t.Context())
	require.NoError(t, err)
	require.Len(t, got, 2)
	require.Equal(t, Invoice{
		Kind: "Termijnnota", PeriodStart: "2026-11-01", PeriodEnd: "2026-12-01",
		Due: "2026-10-26", AmountEUR: 150, Paid: true,
	}, got[0])
	require.InDelta(t, -300.5, got[1].AmountEUR, 1e-9)
	require.NotContains(t, fmt.Sprintf("%+v", got), "PRIVATE")
}

func TestInvoicesEmptyListIsAnError(t *testing.T) {
	b := newBackend(t)
	b.set("DataActionGetInvoicesByUserId_API", `{"data":{"Str_Out_Invoice_V3":{"List":[]}}}`)
	c := b.client(t)

	_, err := c.Invoices(t.Context())
	require.ErrorIs(t, err, ErrEmptyReply)
}

// Replies carry name, address and IBAN, so no error may quote one.
func TestErrorsNeverQuoteTheReply(t *testing.T) {
	b := newBackend(t)
	b.set("ActionGetContractAndAccountDataToSync", `{"data":{"SyncContractData":{"ContractId":"not-a-number","DeliveryCity":"PRIVATE"}}}`)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.Error(t, err)
	require.NotContains(t, err.Error(), "PRIVATE")

	var syntax *json.SyntaxError
	require.False(t, errors.As(err, &syntax))
}

func TestCallsAreSpacedOut(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)
	c.minGap = 40 * time.Millisecond

	start := time.Now()
	_, err := c.Contract(t.Context()) // two calls: login, sync
	require.NoError(t, err)
	require.GreaterOrEqual(t, time.Since(start), c.minGap)
}

// The rejection's exact shape has never been observed, so any refusal counts.
func TestLoginHTTPRefusalBlocks(t *testing.T) {
	for _, code := range []int{http.StatusUnauthorized, http.StatusForbidden, http.StatusTooManyRequests} {
		b := newBackend(t)
		b.status["ActionDoLogin"] = code
		c := b.client(t)

		_, err := c.Contract(t.Context())
		require.ErrorIs(t, err, ErrLoginRejected, "HTTP %d", code)
		require.True(t, c.LoginBlocked())

		_, err = c.Contract(t.Context())
		require.ErrorIs(t, err, ErrLoginRejected)
		require.Equal(t, 1, b.logins, "HTTP %d", code)
	}
}

// A server fault says nothing about the password, so it must not stop logins for
// a day. Spacing still limits the retries.
func TestLoginServerFaultDoesNotBlock(t *testing.T) {
	b := newBackend(t)
	b.status["ActionDoLogin"] = http.StatusBadGateway
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.Error(t, err)
	require.False(t, c.LoginBlocked())

	_, err = c.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginSpacing)
	require.Equal(t, 1, b.logins)
}

// A real session cookie carries a non-zero uid. Anything else is a refusal that
// merely looks like success.
func TestLoginWithoutProofOfSessionBlocks(t *testing.T) {
	for _, cookie := range []string{"", "crf%3Dtoken-1", "uid%3D0%3Bcrf%3Dtoken-1"} {
		b := newBackend(t)
		b.set("loginCookie", cookie)
		c := b.client(t)

		_, err := c.Contract(t.Context())
		require.ErrorIs(t, err, ErrLoginRejected, "cookie %q", cookie)
		require.True(t, c.LoginBlocked())
	}
}

type memoryStore struct{ last, blocked time.Time }

func (m *memoryStore) LoadLogin(context.Context) (time.Time, time.Time, error) {
	return m.last, m.blocked, nil
}

func (m *memoryStore) SaveLogin(_ context.Context, last, blocked time.Time) error {
	m.last, m.blocked = last, blocked

	return nil
}

// A crash loop or a deploy must not turn into repeated password attempts.
func TestBlockAndSpacingSurviveARestart(t *testing.T) {
	b := newBackend(t)
	b.set("ActionDoLogin", `{"exception":{"message":"Invalid Login"}}`)
	store := &memoryStore{}

	first := b.client(t)
	require.NoError(t, first.UseLoginStore(t.Context(), store))
	_, err := first.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginRejected)

	second := b.client(t)
	require.NoError(t, second.UseLoginStore(t.Context(), store))
	require.True(t, second.LoginBlocked())
	_, err = second.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginRejected)
	require.Equal(t, 1, b.logins)

	store.blocked = time.Time{}
	third := b.client(t)
	require.NoError(t, third.UseLoginStore(t.Context(), store))
	_, err = third.Contract(t.Context())
	require.ErrorIs(t, err, ErrLoginSpacing, "spacing survives a restart too")
	require.Equal(t, 1, b.logins)
}

// Expiry can arrive as a status, not only as the one exception name ever seen.
func TestHTTPForbiddenOnADataCallExpiresTheSession(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.NoError(t, err)

	now := time.Now()
	c.now = func() time.Time { return now }
	c.lastLogin = now.Add(-2 * loginSpacing)
	b.status["DataActionGetInvoicesByUserId_API"] = http.StatusForbidden

	_, err = c.Invoices(t.Context())
	require.Error(t, err)
	require.Equal(t, 2, b.logins, "one fresh login, then give up")
	require.False(t, c.LoginBlocked())
}

func TestResetMakesTheNextCallLogInAgainWithFreshCookies(t *testing.T) {
	b := newBackend(t)
	c := b.client(t)

	_, err := c.Contract(t.Context())
	require.NoError(t, err)

	c.lastLogin = time.Now().Add(-2 * loginSpacing)
	c.Reset()
	c.contract = nil

	_, err = c.Contract(t.Context())
	require.NoError(t, err)
	require.Equal(t, 2, b.logins)
	require.NotContains(t, b.cookies[1], sessionCookie, "a new login must not carry the old session")
}
