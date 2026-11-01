-- energyd schema. Source of truth for squibble: the live database is migrated to
-- match this file exactly (see db.go).
--
-- No personal data belongs here: no name, address, email, phone, IBAN, EAN,
-- contract or invoice number. TestSchemaHoldsNoPersonalData enforces it.
--
-- Instants are unix seconds. Local days are YYYY-MM-DD in Europe/Amsterdam.

-- meter_readings keeps the P1 registers at the first reading of each 15-minute
-- period. The next row's registers close the period, so a missed poll costs
-- attribution, never volume.
CREATE TABLE meter_readings (
    period_start INTEGER PRIMARY KEY,
    read_at      INTEGER NOT NULL,
    import_kwh   REAL NOT NULL,
    export_kwh   REAL NOT NULL,
    gas_m3       REAL NOT NULL
);

-- prices holds market prices excluding VAT, at whatever resolution the feed
-- publishes: quarters or hours for electricity, a gas day for gas.
CREATE TABLE prices (
    energy       TEXT NOT NULL,
    period_start INTEGER NOT NULL,
    period_end   INTEGER NOT NULL,
    eur_ex_vat   REAL NOT NULL,
    PRIMARY KEY (energy, period_start)
) WITHOUT ROWID;

-- supplier_days holds NextEnergy's daily figures. A row exists only once both
-- utilities were read for the day, so a missing row means "read it again".
CREATE TABLE supplier_days (
    day                TEXT PRIMARY KEY,
    status             TEXT NOT NULL,
    elec_kwh           REAL NOT NULL,
    elec_delivery_eur  REAL NOT NULL,
    elec_tax_eur       REAL NOT NULL,
    elec_fixed_eur     REAL NOT NULL,
    elec_total_eur     REAL NOT NULL,
    gas_m3             REAL NOT NULL,
    gas_delivery_eur   REAL NOT NULL,
    gas_tax_eur        REAL NOT NULL,
    gas_fixed_eur      REAL NOT NULL,
    gas_total_eur      REAL NOT NULL,
    fetched_at         INTEGER NOT NULL
);

-- supplier_hours holds hourly volume per utility, scaled to the day total.
CREATE TABLE supplier_hours (
    utility    TEXT NOT NULL,
    hour_start INTEGER NOT NULL,
    volume     REAL NOT NULL,
    PRIMARY KEY (utility, hour_start)
) WITHOUT ROWID;

-- fees holds the contract's supplier fee per kWh or m³, excluding VAT.
CREATE TABLE fees (
    utility    TEXT NOT NULL,
    valid_from TEXT NOT NULL,
    valid_to   TEXT NOT NULL,
    eur_ex_vat REAL NOT NULL,
    PRIMARY KEY (utility, valid_from)
) WITHOUT ROWID;

-- bills is replaced whole on every read, since nothing here identifies a bill.
CREATE TABLE bills (
    kind         TEXT NOT NULL,
    period_start TEXT NOT NULL,
    period_end   TEXT NOT NULL,
    due          TEXT NOT NULL,
    amount_eur   REAL NOT NULL,
    paid         INTEGER NOT NULL,
    credited     INTEGER NOT NULL
);

-- login_state survives restarts, so a crash loop cannot become repeated password
-- attempts. Zero means no time.
CREATE TABLE login_state (
    id            INTEGER PRIMARY KEY CHECK (id = 1),
    last_attempt  INTEGER NOT NULL,
    blocked_until INTEGER NOT NULL
);

-- weather_days holds the daily mean outdoor temperature for degree days.
CREATE TABLE weather_days (
    day    TEXT PRIMARY KEY,
    mean_c REAL NOT NULL
);

-- weather_hours holds yr.no's temperature per hour. yr.no only looks forward, so
-- each hour keeps the last forecast made for it, and days are built from these.
CREATE TABLE weather_hours (
    hour_ts INTEGER PRIMARY KEY,
    temp_c  REAL NOT NULL
);
