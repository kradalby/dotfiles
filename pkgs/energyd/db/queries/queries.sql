-- name: InsertReading :exec
INSERT INTO meter_readings (period_start, read_at, import_kwh, export_kwh, gas_m3)
VALUES (?, ?, ?, ?, ?)
ON CONFLICT (period_start) DO NOTHING;

-- name: ReadingsBetween :many
SELECT * FROM meter_readings
WHERE period_start >= sqlc.arg(from_ts) AND period_start <= sqlc.arg(to_ts)
ORDER BY period_start;

-- name: LastReadingBefore :one
SELECT * FROM meter_readings
WHERE period_start < sqlc.arg(ts)
ORDER BY period_start DESC
LIMIT 1;

-- name: UpsertPrice :exec
INSERT INTO prices (energy, period_start, period_end, eur_ex_vat)
VALUES (?, ?, ?, ?)
ON CONFLICT (energy, period_start) DO UPDATE SET
    period_end = excluded.period_end,
    eur_ex_vat = excluded.eur_ex_vat;

-- name: PricesBetween :many
SELECT * FROM prices
WHERE energy = sqlc.arg(energy)
  AND period_end > sqlc.arg(from_ts)
  AND period_start < sqlc.arg(to_ts)
ORDER BY period_start;

-- name: UpsertSupplierDay :exec
INSERT INTO supplier_days (
    day, status, elec_kwh, elec_delivery_eur, elec_tax_eur, elec_fixed_eur, elec_total_eur,
    gas_m3, gas_delivery_eur, gas_tax_eur, gas_fixed_eur, gas_total_eur, fetched_at
) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
ON CONFLICT (day) DO UPDATE SET
    status = excluded.status,
    elec_kwh = excluded.elec_kwh,
    elec_delivery_eur = excluded.elec_delivery_eur,
    elec_tax_eur = excluded.elec_tax_eur,
    elec_fixed_eur = excluded.elec_fixed_eur,
    elec_total_eur = excluded.elec_total_eur,
    gas_m3 = excluded.gas_m3,
    gas_delivery_eur = excluded.gas_delivery_eur,
    gas_tax_eur = excluded.gas_tax_eur,
    gas_fixed_eur = excluded.gas_fixed_eur,
    gas_total_eur = excluded.gas_total_eur,
    fetched_at = excluded.fetched_at;

-- name: SupplierDaysBetween :many
SELECT * FROM supplier_days
WHERE day >= sqlc.arg(from_day) AND day <= sqlc.arg(to_day)
ORDER BY day;

-- name: NewestSupplierDayWithElectricity :one
SELECT * FROM supplier_days
WHERE elec_kwh > 0 AND day <= sqlc.arg(to_day)
ORDER BY day DESC
LIMIT 1;

-- name: NewestSupplierDayWithGas :one
SELECT * FROM supplier_days
WHERE gas_m3 > 0 AND day <= sqlc.arg(to_day)
ORDER BY day DESC
LIMIT 1;

-- name: UpsertSupplierHour :exec
INSERT INTO supplier_hours (utility, hour_start, volume)
VALUES (?, ?, ?)
ON CONFLICT (utility, hour_start) DO UPDATE SET volume = excluded.volume;

-- name: SupplierHoursBetween :many
SELECT * FROM supplier_hours
WHERE utility = sqlc.arg(utility)
  AND hour_start >= sqlc.arg(from_ts)
  AND hour_start < sqlc.arg(to_ts)
ORDER BY hour_start;

-- name: UpsertFee :exec
INSERT INTO fees (utility, valid_from, valid_to, eur_ex_vat)
VALUES (?, ?, ?, ?)
ON CONFLICT (utility, valid_from) DO UPDATE SET
    valid_to = excluded.valid_to,
    eur_ex_vat = excluded.eur_ex_vat;

-- name: ListFees :many
SELECT * FROM fees ORDER BY utility, valid_from;

-- name: DeleteBills :exec
DELETE FROM bills;

-- name: InsertBill :exec
INSERT INTO bills (kind, period_start, period_end, due, amount_eur, paid, credited)
VALUES (?, ?, ?, ?, ?, ?, ?);

-- name: ListBills :many
SELECT * FROM bills ORDER BY period_start, kind;

-- name: GetLoginState :one
SELECT * FROM login_state WHERE id = 1;

-- name: UpsertLoginState :exec
INSERT INTO login_state (id, last_attempt, blocked_until) VALUES (1, ?, ?)
ON CONFLICT (id) DO UPDATE SET
    last_attempt = excluded.last_attempt,
    blocked_until = excluded.blocked_until;

-- name: UpsertWeather :exec
INSERT INTO weather_days (day, mean_c) VALUES (?, ?)
ON CONFLICT (day) DO UPDATE SET mean_c = excluded.mean_c;

-- name: InsertWeatherIfMissing :exec
INSERT INTO weather_days (day, mean_c) VALUES (?, ?)
ON CONFLICT (day) DO NOTHING;

-- name: UpsertWeatherHour :exec
INSERT INTO weather_hours (hour_ts, temp_c) VALUES (?, ?)
ON CONFLICT (hour_ts) DO UPDATE SET temp_c = excluded.temp_c;

-- name: WeatherHoursBetween :many
SELECT * FROM weather_hours
WHERE hour_ts >= sqlc.arg(from_ts) AND hour_ts < sqlc.arg(to_ts)
ORDER BY hour_ts;

-- name: WeatherBetween :many
SELECT * FROM weather_days
WHERE day >= sqlc.arg(from_day) AND day <= sqlc.arg(to_day)
ORDER BY day;
