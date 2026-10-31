# energyd

Ledger of what energy costs this home. It reads NextEnergy's app backend, EnergyZero day-ahead prices, the HomeWizard P1 meter and Open-Meteo into SQLite. It serves `/metrics` and a JSON API on localhost for Prometheus and Grafana's Infinity datasource. The Leiden dashboard that charts it lives in `pkgs/dashboards`, because it charts other services too.

NextEnergy has no customer API. The client speaks the app's undocumented protocol, and may break without notice.

## Money

- NextEnergy's day totals are what it reports. They land about a day late and can be corrected, so each poll re-reads the last week.
- Everything else is computed: `kWh x ((hour mean price + fee) x VAT + tax)`, with fee and tax read from the account.
- Daily figures are not the bill. The contract-years panel shows the difference.

## Run

```sh
nix develop --command go test ./...
direnv exec . go run ./cmd/energyd --db-path /tmp/energyd.db
```

`.envrc` loads `NEXTENERGY_USERNAME` and `NEXTENERGY_PASSWORD` from setec. Production reads them from `secrets/energyd.age`.

One rejected login stops login attempts for a day, so a wrong password cannot lock the account. The block survives restarts. To clear it after fixing the credentials:

```sh
systemctl start energyd-unblock
systemctl restart energyd
```

Without credentials the service still reads the meter, prices and weather.

## Backfill

```sh
systemctl start energyd-backfill
```

It goes back to the contract start, newest day first, at about one NextEnergy call per 5 seconds, and stops at the first failure. Starting it again resumes at the newest missing day. It waits if the service logged in during the last hour.

## When `EnergydApiVersionChanged` fires

A stale `apiVersion` answers HTTP 200 with empty data. To fix it:

1. Fetch `https://mijn.nextenergy.nl/Mobile_EnergyNext/moduleservices/moduleinfo` and find the action's versioned screen script.
2. Read the new `apiVersion` from the `callDataAction` or `callServerAction` call in that script.
3. Update the `action` table in `nextenergy/client.go`.

## Schema

`db/schema.sql` is the source of truth. After changing a query or the schema, run:

```sh
nix run nixpkgs#sqlc -- generate
```

No personal data belongs in the database, and `TestSchemaHoldsNoPersonalData` enforces that.
