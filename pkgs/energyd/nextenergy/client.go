// Package nextenergy reads one customer's data from NextEnergy's app backend.
//
// NextEnergy has no customer API. The mobile app is an OutSystems application,
// so this client speaks its "screenservices" JSON protocol. Every action needs
// the module version read at login and its own apiVersion from the app bundles.
// A stale apiVersion answers HTTP 200 with empty data and a flag, so status codes
// say nothing about health.
//
// Replies carry name, address, email and IBAN. Decode only the fields a type
// below names, and never put a reply into a log or an error.
package nextenergy

import (
	"bytes"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/http/cookiejar"
	"net/url"
	"regexp"
	"strconv"
	"strings"
	"sync"
	"time"

	"energyd/tz"
)

const (
	defaultBaseURL = "https://mijn.nextenergy.nl/Mobile_EnergyNext"
	sessionCookie  = "nr2Users_Customers"
	maxReplyBytes  = 32 << 20

	// loginSpacing bounds login attempts when a session expires repeatedly.
	loginSpacing = time.Hour
	// loginBlock is how long one rejected password stops all attempts. Login
	// rate limits are unknown, and a timer retrying a wrong password could lock
	// the account. It survives restarts; `energyd unblock` clears it.
	loginBlock = 24 * time.Hour
	// defaultMinGap paces every call: the data is a day late, so nothing here
	// needs speed, and backfill is thousands of calls on a real account.
	defaultMinGap = 5 * time.Second

	dayMissing = "MISS"

	// A local day has 23, 24 or 25 hours. Fewer points means a broken reply.
	minDayPoints = 23
	maxDayPoints = 25
)

// Utility identifies a metered energy type. Values are the app's own ids.
type Utility int

const (
	Gas         Utility = 1
	Electricity Utility = 2
)

func (u Utility) String() string {
	if u == Gas {
		return "gas"
	}

	return "electricity"
}

var (
	// ErrLoginRejected means the backend refused the credentials.
	ErrLoginRejected = errors.New("nextenergy: login rejected")
	// ErrLoginSpacing means a session expired too soon after the last login.
	ErrLoginSpacing = errors.New("nextenergy: login attempted too soon after the last one")
	// ErrAPIVersionChanged means a hard-coded apiVersion needs a bump by hand.
	ErrAPIVersionChanged = errors.New("nextenergy: api version changed")
	// ErrEmptyReply means a call succeeded but returned no usable data.
	ErrEmptyReply = errors.New("nextenergy: empty reply")

	errSessionExpired = errors.New("nextenergy: session expired")
	crfPattern        = regexp.MustCompile(`crf=([^;]+)`)
	uidPattern        = regexp.MustCompile(`uid=([^;]+)`)
)

// action is one screenservices endpoint. view must name the screen that owns the
// action, or the backend answers "No role validation found".
type action struct{ path, apiVersion, view string }

var (
	actionLogin = action{"Mobile_EnergyNext/EntryFlow/Login_New/ActionDoLogin", "6RXNTWQg6FlgienWK8L57A", "EntryFlow.Login_New"}
	actionSync  = action{"Mobile_LocalStorage_BL/ActionGetContractAndAccountDataToSync", "qUSD+Sc+GuaGYdDHGUX1aQ", "MainFlow.Usage"}

	actionUsageScreen = action{"Mobile_EnergyNext_CW/WidgetFlow/Usage_QuarterlyPrices_v2/ActionUsage_GetData", "IkZvZs2aMH7OvfTv2DIswQ", "MainFlow.Usage"}
	actionUsageData   = action{"Mobile_EnergyNext_CW/WidgetFlow/Usage_QuarterlyPrices_v2/DataActionGetUsageData", "fRPUGOfMLbxgQk2uUb+xeg", "MainFlow.Usage"}
	actionFees        = action{"Mobile_EnergyNext_CW/WidgetFlow/MarketPrices_Quarterly_v2/DataActionGetPropositionData", "k+qSvCjIpJRLmow43VyNmA", "MainFlow.MarketPrices"}
	actionInvoices    = action{"Mobile_Profile_CW/Invoices/WB_InvoicesOverview_List/DataActionGetInvoicesByUserId_API", "6Rksw2e_sAJC_zk81erdGQ", "MainFlow.InvoiceOverview"}
)

// LoginStore keeps login state across restarts, so a crash loop cannot become
// repeated password attempts.
type LoginStore interface {
	LoadLogin(ctx context.Context) (lastAttempt, blockedUntil time.Time, err error)
	SaveLogin(ctx context.Context, lastAttempt, blockedUntil time.Time) error
}

// Client talks to the app backend for one account. It is safe for concurrent
// use; calls are serialized and paced.
type Client struct {
	http     *http.Client
	username string
	password string
	// A stable id keeps the backend from seeing a new device on every login.
	deviceID string
	baseURL  string
	minGap   time.Duration
	now      func() time.Time

	mu            sync.Mutex
	lastCall      time.Time
	moduleVersion string
	csrf          string
	lastLogin     time.Time
	blockedUntil  time.Time
	versionStale  bool
	logins        int
	store         LoginStore
	contract      *Contract
	screen        *screenState
}

// New builds a client. It does not touch the network.
func New(username, password string) (*Client, error) {
	jar, err := cookiejar.New(nil)
	if err != nil {
		return nil, fmt.Errorf("cookie jar: %w", err)
	}

	return &Client{
		http:     &http.Client{Jar: jar, Timeout: 30 * time.Second},
		username: username,
		password: password,
		deviceID: "energyd",
		baseURL:  defaultBaseURL,
		minGap:   defaultMinGap,
		now:      time.Now,
	}, nil
}

// UseLoginStore loads saved login state and keeps it saved from now on.
func (c *Client) UseLoginStore(ctx context.Context, store LoginStore) error {
	c.mu.Lock()
	defer c.mu.Unlock()

	last, blocked, err := store.LoadLogin(ctx)
	if err != nil {
		return fmt.Errorf("load login state: %w", err)
	}

	c.store, c.lastLogin, c.blockedUntil = store, last, blocked

	return nil
}

func (c *Client) saveLogin(ctx context.Context) error {
	if c.store == nil {
		return nil
	}

	if err := c.store.SaveLogin(ctx, c.lastLogin, c.blockedUntil); err != nil {
		return fmt.Errorf("save login state: %w", err)
	}

	return nil
}

// Reset drops the session, so the next call logs in again if spacing allows. A
// failed poll may mean a session gone bad in a way nobody has seen yet.
func (c *Client) Reset() {
	c.mu.Lock()
	defer c.mu.Unlock()

	c.csrf = ""
	c.screen = nil
}

// WaitForLogin returns once a login is allowed, for a one-shot command that must
// not fail because another process logged in a moment ago.
func (c *Client) WaitForLogin(ctx context.Context) error {
	c.mu.Lock()
	wait := loginSpacing - c.now().Sub(c.lastLogin)
	c.mu.Unlock()

	if wait <= 0 {
		return nil
	}

	select {
	case <-ctx.Done():
		return ctx.Err()
	case <-time.After(wait):
		return nil
	}
}

// LoginBlocked reports whether a rejected password is stopping login attempts.
func (c *Client) LoginBlocked() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	return c.now().Before(c.blockedUntil)
}

// APIVersionChanged reports whether the newest call found a stale apiVersion.
func (c *Client) APIVersionChanged() bool {
	c.mu.Lock()
	defer c.mu.Unlock()

	return c.versionStale
}

// Logins counts login attempts, so a session that keeps expiring is visible.
func (c *Client) Logins() int {
	c.mu.Lock()
	defer c.mu.Unlock()

	return c.logins
}

func (c *Client) ensureLogin(ctx context.Context) error {
	if c.csrf != "" {
		return nil
	}

	return c.login(ctx)
}

func (c *Client) login(ctx context.Context) error {
	now := c.now()
	if now.Before(c.blockedUntil) {
		return ErrLoginRejected
	}

	if !c.lastLogin.IsZero() && now.Sub(c.lastLogin) < loginSpacing {
		return ErrLoginSpacing
	}

	c.lastLogin = now
	c.logins++
	c.csrf = ""

	// Fail closed: an attempt that cannot be recorded could repeat after a restart.
	if err := c.saveLogin(ctx); err != nil {
		return err
	}

	// A new session must not carry the old one's cookies.
	jar, err := cookiejar.New(nil)
	if err != nil {
		return fmt.Errorf("cookie jar: %w", err)
	}

	c.http.Jar = jar

	if err := c.fetchModuleVersion(ctx); err != nil {
		return err
	}

	err = c.post(ctx, actionLogin, map[string]any{
		"inputParameters": map[string]string{
			"Username": c.username,
			"Password": c.password,
			"DeviceId": c.deviceID,
		},
	}, nil)

	// The rejection's exact shape has never been observed, so anything that is
	// not plainly a fault of the path counts. A false stop costs a day of data at
	// most, and a false retry can lock the account.
	var ex *exceptionError
	if errors.As(err, &ex) || errors.Is(err, errSessionExpired) || isRefusalStatus(err) {
		return c.blockLogin(ctx, now)
	}

	if err != nil {
		return fmt.Errorf("login: %w", err)
	}

	csrf, err := c.readSession()
	if err != nil {
		return c.blockLogin(ctx, now)
	}

	c.csrf = csrf
	c.blockedUntil = time.Time{}

	return c.saveLogin(ctx)
}

func (c *Client) blockLogin(ctx context.Context, now time.Time) error {
	c.blockedUntil = now.Add(loginBlock)

	return errors.Join(ErrLoginRejected, c.saveLogin(ctx))
}

// isRefusalStatus reports a status that answers "no", unlike a server fault.
func isRefusalStatus(err error) bool {
	var status *httpStatusError

	return errors.As(err, &status) &&
		(status.code == http.StatusUnauthorized || status.code == http.StatusForbidden || status.code == http.StatusTooManyRequests)
}

func isAuthStatus(err error) bool {
	var status *httpStatusError

	return errors.As(err, &status) && (status.code == http.StatusUnauthorized || status.code == http.StatusForbidden)
}

func (c *Client) fetchModuleVersion(ctx context.Context) error {
	// The login page sets cookies the login action expects.
	if _, err := c.get(ctx, "/Login"); err != nil {
		return err
	}

	body, err := c.get(ctx, "/moduleservices/moduleversioninfo")
	if err != nil {
		return err
	}

	var info struct {
		VersionToken string `json:"versionToken"`
	}
	if err := json.Unmarshal(body, &info); err != nil {
		return errors.New("nextenergy: decode module version")
	}

	if info.VersionToken == "" {
		return fmt.Errorf("%w: module version", ErrEmptyReply)
	}

	c.moduleVersion = info.VersionToken

	return nil
}

// readSession proves the login worked and returns the CSRF token. The session
// cookie only appears after a login, and carries a non-zero uid.
func (c *Client) readSession() (string, error) {
	base, err := url.Parse(c.baseURL)
	if err != nil {
		return "", fmt.Errorf("parse base url: %w", err)
	}

	for _, cookie := range c.http.Jar.Cookies(base) {
		if cookie.Name != sessionCookie {
			continue
		}

		value, err := url.QueryUnescape(cookie.Value)
		if err != nil {
			return "", errors.New("nextenergy: decode session cookie")
		}

		uid, csrf := uidPattern.FindStringSubmatch(value), crfPattern.FindStringSubmatch(value)
		if uid != nil && uid[1] != "0" && csrf != nil {
			return csrf[1], nil
		}
	}

	return "", fmt.Errorf("%w: no session after login", ErrEmptyReply)
}

func (c *Client) get(ctx context.Context, path string) ([]byte, error) {
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, c.baseURL+path, nil)
	if err != nil {
		return nil, fmt.Errorf("build request: %w", err)
	}

	return c.do(req)
}

func (c *Client) do(req *http.Request) ([]byte, error) {
	resp, err := c.http.Do(req)
	if err != nil {
		return nil, fmt.Errorf("nextenergy: request: %w", err)
	}
	defer func() { _ = resp.Body.Close() }()

	if resp.StatusCode != http.StatusOK {
		return nil, &httpStatusError{code: resp.StatusCode}
	}

	body, err := io.ReadAll(io.LimitReader(resp.Body, maxReplyBytes))
	if err != nil {
		return nil, fmt.Errorf("nextenergy: read reply: %w", err)
	}

	return body, nil
}

type httpStatusError struct{ code int }

func (e *httpStatusError) Error() string { return fmt.Sprintf("nextenergy: HTTP %d", e.code) }

// exceptionError is an application error the backend reported in a 200 reply.
type exceptionError struct{ name, message string }

func (e *exceptionError) Error() string {
	return fmt.Sprintf("nextenergy: backend exception %s: %s", e.name, e.message)
}

func (c *Client) pace(ctx context.Context) error {
	if wait := c.minGap - c.now().Sub(c.lastCall); wait > 0 && !c.lastCall.IsZero() {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(wait):
		}
	}

	c.lastCall = c.now()

	return nil
}

// post calls one action and decodes its data field into out. It never returns
// reply content, except the backend's own exception message.
func (c *Client) post(ctx context.Context, a action, fields map[string]any, out any) error {
	if err := c.pace(ctx); err != nil {
		return err
	}

	payload := map[string]any{
		"versionInfo": map[string]string{"moduleVersion": c.moduleVersion, "apiVersion": a.apiVersion},
		"viewName":    a.view,
	}
	for k, v := range fields {
		payload[k] = v
	}

	raw, err := json.Marshal(payload)
	if err != nil {
		return fmt.Errorf("encode request: %w", err)
	}

	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.baseURL+"/screenservices/"+a.path, bytes.NewReader(raw))
	if err != nil {
		return fmt.Errorf("build request: %w", err)
	}

	req.Header.Set("Content-Type", "application/json; charset=UTF-8")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("OutSystems-locale", "nl-NL")
	// Empty but present before login: the backend answers "Invalid Login" to
	// valid credentials when the header is absent.
	req.Header.Set("X-CSRFToken", c.csrf)

	body, err := c.do(req)
	if err != nil {
		return err
	}

	var reply struct {
		VersionInfo struct {
			APIChanged bool `json:"hasApiVersionChanged"`
		} `json:"versionInfo"`
		Exception *struct {
			Name    string `json:"name"`
			Message string `json:"message"`
		} `json:"exception"`
		Data json.RawMessage `json:"data"`
	}
	if err := json.Unmarshal(body, &reply); err != nil {
		return errors.New("nextenergy: decode reply envelope")
	}

	c.versionStale = reply.VersionInfo.APIChanged
	if reply.VersionInfo.APIChanged {
		return fmt.Errorf("%w: %s", ErrAPIVersionChanged, a.path)
	}

	if ex := reply.Exception; ex != nil {
		switch {
		case ex.Name == "NotRegistered":
			return errSessionExpired
		case strings.Contains(strings.ToLower(ex.Message), "version"):
			c.versionStale = true

			return fmt.Errorf("%w: %s", ErrAPIVersionChanged, a.path)
		}

		return &exceptionError{name: ex.Name, message: ex.Message}
	}

	if out == nil {
		return nil
	}

	if err := json.Unmarshal(reply.Data, out); err != nil {
		// A decode error can quote the offending value, so it stays out.
		return fmt.Errorf("nextenergy: decode reply of %s", a.path)
	}

	return nil
}

// call runs an action, logging in first if needed and once more if the session
// has expired. Login spacing keeps this from becoming a retry loop.
func (c *Client) call(ctx context.Context, a action, fields map[string]any, out any) error {
	if err := c.ensureLogin(ctx); err != nil {
		return err
	}

	err := c.post(ctx, a, fields, out)
	if !errors.Is(err, errSessionExpired) && !isAuthStatus(err) {
		return err
	}

	c.csrf = ""
	c.screen = nil

	if err := c.login(ctx); err != nil {
		return err
	}

	return c.post(ctx, a, fields, out)
}

// number decodes the backend's numbers, which arrive as JSON strings.
type number float64

func (n *number) UnmarshalJSON(b []byte) error {
	s := strings.Trim(string(b), `"`)
	if s == "" || s == "null" {
		*n = 0

		return nil
	}

	v, err := strconv.ParseFloat(s, 64)
	if err != nil {
		return errors.New("not a number")
	}

	*n = number(v)

	return nil
}

// Contract is the only contract data energyd keeps.
type Contract struct {
	ID     int64
	HasGas bool
}

// Contract returns the account's contract, cached for the client's lifetime.
func (c *Client) Contract(ctx context.Context) (Contract, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	return c.loadContract(ctx)
}

func (c *Client) loadContract(ctx context.Context) (Contract, error) {
	if c.contract != nil {
		return *c.contract, nil
	}

	var data struct {
		Contract struct {
			ID string `json:"ContractId"`
		} `json:"SyncContractData"`
		Lines struct {
			HasGas bool `json:"HasGas"`
		} `json:"SyncContractlineIntervals"`
	}

	err := c.call(ctx, actionSync, map[string]any{"inputParameters": map[string]any{}}, &data)
	if err != nil {
		return Contract{}, err
	}

	id, err := strconv.ParseInt(data.Contract.ID, 10, 64)
	if err != nil || id == 0 {
		return Contract{}, fmt.Errorf("%w: no contract id", ErrEmptyReply)
	}

	c.contract = &Contract{ID: id, HasGas: data.Lines.HasGas}

	return *c.contract, nil
}

// screenState is what the widget keeps in its model. Data actions want it sent
// back verbatim, or they fail with a generic error. It holds contract details,
// so it stays in memory and is only ever returned to the backend.
type screenState struct {
	Variables    json.RawMessage `json:"Out_ScreenVariables"`
	ContractInfo json.RawMessage `json:"Out_ContractInfo"`
}

func (c *Client) loadScreen(ctx context.Context, day time.Time) (*screenState, error) {
	if c.screen != nil {
		return c.screen, nil
	}

	var data screenState

	// The action only accepts id 0 and resolves the contract from the session.
	err := c.call(ctx, actionUsageScreen, map[string]any{"inputParameters": map[string]any{
		"In_ContractId": 0,
		"In_PriceDate":  tz.DateString(day),
	}}, &data)
	if err != nil {
		return nil, err
	}

	if len(data.Variables) == 0 {
		return nil, fmt.Errorf("%w: usage screen", ErrEmptyReply)
	}

	c.screen = &data

	return c.screen, nil
}

func (c *Client) screenVariables(contract Contract, day time.Time, screen *screenState, extra map[string]any) map[string]any {
	vars := map[string]any{
		"In_ContractId":                   contract.ID,
		"_in_ContractIdInDataFetchStatus": 1,
		"In_DateTime":                     tz.DateString(day) + "T00:00:00Z",
		"_in_DateTimeInDataFetchStatus":   1,
		"ScreenVariables":                 screen.Variables,
		"ContractInfo":                    screen.ContractInfo,
	}
	for k, v := range extra {
		vars[k] = v
	}

	return vars
}

// UtilityTotals is one utility's figures for a day, as NextEnergy reports them.
type UtilityTotals struct {
	Volume   float64
	Delivery float64
	Tax      float64
	Fixed    float64
}

// Hour is one hour's volume for the requested utility.
type Hour struct {
	Start  time.Time
	Volume float64
}

// Day is one local day. Totals are the same whichever utility was requested;
// Hours belong to the requested utility.
type Day struct {
	Date      time.Time
	Status    string
	Elec      UtilityTotals
	Gas       UtilityTotals
	TotalElec float64
	TotalGas  float64
	Hours     []Hour
}

// Missing reports that the grid operator has not delivered this day yet.
func (d Day) Missing() bool { return d.Status == dayMissing }

type totalsRecord struct {
	Volume   number `json:"DeliveryVolume"`
	Delivery number `json:"DeliveryCosts"`
	Tax      number `json:"EnergyTax"`
	Fixed    number `json:"FixedCosts"`
}

func (t totalsRecord) totals() UtilityTotals {
	return UtilityTotals{
		Volume: float64(t.Volume), Delivery: float64(t.Delivery),
		Tax: float64(t.Tax), Fixed: float64(t.Fixed),
	}
}

// Usage reads one local day. A day not yet delivered is not an error: check
// Missing. Empty points on a delivered day are, because that is how a broken
// reply looks.
func (c *Client) Usage(ctx context.Context, day time.Time, u Utility) (Day, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	contract, err := c.loadContract(ctx)
	if err != nil {
		return Day{}, err
	}

	screen, err := c.loadScreen(ctx, day)
	if err != nil {
		return Day{}, err
	}

	date := tz.DateString(day)

	var data struct {
		Status string `json:"DayStatusId"`
		Totals struct {
			TotalElec number       `json:"TotalElecEuro"`
			TotalGas  number       `json:"TotalGasEuro"`
			Elec      totalsRecord `json:"Elec"`
			Gas       totalsRecord `json:"Gas"`
		} `json:"TotalsPerPeriod"`
		Points struct {
			List []struct {
				Label  string `json:"Label"`
				Value  number `json:"Value"`
				Series string `json:"SeriesName"`
			} `json:"List"`
		} `json:"DataPoints"`
	}

	err = c.call(ctx, actionUsageData, map[string]any{
		"screenData": map[string]any{
			"variables": c.screenVariables(contract, day, screen, map[string]any{
				"ViewVariables": map[string]bool{"SeenElec": true, "SeenGas": true},
			}),
		},
		"clientVariables": map[string]any{
			"UsageDate":          date,
			"UsageYear":          day.In(tz.Amsterdam).Year(),
			"DistributionId":     3, // one point per hour of the selected day
			"UsageUtilityTypeId": int(u),
			"UsageCostLevelId":   "",
			"PriceCostLevel":     "",
			"PriceDate":          date,
		},
	}, &data)
	if err != nil {
		return Day{}, err
	}

	out := Day{
		Date:      tz.Day(day),
		Status:    data.Status,
		Elec:      data.Totals.Elec.totals(),
		Gas:       data.Totals.Gas.totals(),
		TotalElec: float64(data.Totals.TotalElec),
		TotalGas:  float64(data.Totals.TotalGas),
	}
	if out.Missing() {
		return out, nil
	}

	// A reply can succeed and say nothing, and that must not overwrite good days.
	if out.Elec.Volume <= 0 {
		return Day{}, fmt.Errorf("%w: usage %s has no volume", ErrEmptyReply, date)
	}

	byStart := map[int64]float64{}
	var order []int64
	var parsed int

	for _, p := range data.Points.List {
		if !matchesSeries(u, p.Series) {
			continue
		}

		start, ok := hourStart(out.Date, p.Label)
		if !ok {
			continue
		}

		parsed++

		// A DST label can name a skipped or repeated hour. Summing keeps the
		// volume, at the cost of attributing it to the neighbouring hour.
		key := start.Unix()
		if _, seen := byStart[key]; !seen {
			order = append(order, key)
		}

		byStart[key] += float64(p.Value)
	}

	if parsed < minDayPoints || parsed > maxDayPoints {
		return Day{}, fmt.Errorf("%w: usage %s has %d hours", ErrEmptyReply, date, parsed)
	}

	total := out.Elec.Volume
	if u == Gas {
		total = out.Gas.Volume
	}

	out.Hours = scale(order, byStart, total)

	return out, nil
}

func matchesSeries(u Utility, name string) bool {
	if u == Gas {
		return strings.EqualFold(name, "gas")
	}

	return strings.EqualFold(name, "stroom")
}

func hourStart(day time.Time, label string) (time.Time, bool) {
	clock, err := time.Parse(time.TimeOnly, strings.TrimSpace(label))
	if err != nil {
		return time.Time{}, false
	}

	y, m, d := day.Date()

	return time.Date(y, m, d, clock.Hour(), clock.Minute(), 0, 0, tz.Amsterdam), true
}

// scale stretches the rounded hourly points so they add up to the exact day
// total, which is what NextEnergy bills.
func scale(order []int64, byStart map[int64]float64, total float64) []Hour {
	var sum float64
	for _, v := range byStart {
		sum += v
	}

	factor := 1.0
	if sum > 0 && total > 0 {
		factor = total / sum
	}

	hours := make([]Hour, 0, len(order))
	for _, key := range order {
		hours = append(hours, Hour{Start: time.Unix(key, 0).UTC(), Volume: byStart[key] * factor})
	}

	return hours
}

// Fee is a contract's supplier fee per kWh or m³, excluding VAT.
type Fee struct {
	Utility   Utility
	EURExVAT  float64
	ValidFrom string
	ValidTo   string
}

// Fees reads the contract's current fees. The contract action's price fields
// are all zeros; this action carries the real ones.
func (c *Client) Fees(ctx context.Context, day time.Time) ([]Fee, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	contract, err := c.loadContract(ctx)
	if err != nil {
		return nil, err
	}

	screen, err := c.loadScreen(ctx, day)
	if err != nil {
		return nil, err
	}

	type proposition struct {
		Price number `json:"Price"`
		Start string `json:"StartDateTariff"`
		End   string `json:"EndDateTariff"`
	}

	var data struct {
		Proposition struct {
			Electricity proposition `json:"Electricity"`
			Gas         proposition `json:"Gas"`
		} `json:"OutContractProposition"`
	}

	err = c.call(ctx, actionFees, map[string]any{
		"screenData": map[string]any{"variables": c.screenVariables(contract, day, screen, nil)},
		"clientVariables": map[string]any{
			"PriceCostLevel": "TotalPrice",
			"PriceDate":      tz.DateString(day),
		},
	}, &data)
	if err != nil {
		return nil, err
	}

	if data.Proposition.Electricity.Price == 0 {
		return nil, fmt.Errorf("%w: fees", ErrEmptyReply)
	}

	fees := []Fee{{
		Utility:   Electricity,
		EURExVAT:  float64(data.Proposition.Electricity.Price),
		ValidFrom: data.Proposition.Electricity.Start,
		ValidTo:   emptyDate(data.Proposition.Electricity.End),
	}}

	if contract.HasGas {
		if data.Proposition.Gas.Price == 0 {
			return nil, fmt.Errorf("%w: gas fee", ErrEmptyReply)
		}

		fees = append(fees, Fee{
			Utility:   Gas,
			EURExVAT:  float64(data.Proposition.Gas.Price),
			ValidFrom: data.Proposition.Gas.Start,
			ValidTo:   emptyDate(data.Proposition.Gas.End),
		})
	}

	return fees, nil
}

// emptyDate maps OutSystems' null date to no date.
func emptyDate(s string) string {
	if strings.HasPrefix(s, "1900-01-01") {
		return ""
	}

	return s
}

// Invoice is one bill. The invoice number stays out on purpose.
type Invoice struct {
	Kind        string // Termijnnota is a monthly advance, Jaarnota an annual settlement.
	PeriodStart string
	PeriodEnd   string
	Due         string
	AmountEUR   float64
	Paid        bool
	Credited    bool
}

// Invoices lists every bill on the contract.
func (c *Client) Invoices(ctx context.Context) ([]Invoice, error) {
	c.mu.Lock()
	defer c.mu.Unlock()

	contract, err := c.loadContract(ctx)
	if err != nil {
		return nil, err
	}

	var data struct {
		Invoices struct {
			List []struct {
				Period struct {
					Start string `json:"StartDate"`
					End   string `json:"EndDate"`
				} `json:"Period"`
				Due      string `json:"DueDate"`
				Credited bool   `json:"IsCredited"`
				Paid     bool   `json:"IsPaid"`
				Type     struct {
					Label string `json:"InvoiceTypeLabel"`
				} `json:"Str_Out_InvoiceType"`
				Amount number `json:"TotalAmountIncludingVAT"`
			} `json:"List"`
		} `json:"Str_Out_Invoice_V3"`
	}

	err = c.call(ctx, actionInvoices, map[string]any{
		"screenData": map[string]any{"variables": map[string]any{
			"ContractId":                   contract.ID,
			"_contractIdInDataFetchStatus": 1,
			"DateTime":                     c.now().UTC().Format(time.RFC3339),
			"_dateTimeInDataFetchStatus":   1,
			"Filter_InvoiceFilterId":       0,
			"ListInvoiceType":              "",
		}},
		"clientVariables": map[string]any{},
	}, &data)
	if err != nil {
		return nil, err
	}

	if len(data.Invoices.List) == 0 {
		return nil, fmt.Errorf("%w: invoices", ErrEmptyReply)
	}

	out := make([]Invoice, 0, len(data.Invoices.List))
	for _, i := range data.Invoices.List {
		out = append(out, Invoice{
			Kind:        i.Type.Label,
			PeriodStart: i.Period.Start,
			PeriodEnd:   i.Period.End,
			Due:         i.Due,
			AmountEUR:   float64(i.Amount),
			Paid:        i.Paid,
			Credited:    i.Credited,
		})
	}

	return out, nil
}
