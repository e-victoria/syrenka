# syrenka-ingest

Data ingestion, normalization and analysis. Python owns everything on this side of the boundary: it has no public routes, and the frontend never talks to it.

Currently: GIOŚ air quality. Later: weather, OSM places, tree crowns, prices, scoring.

---

## Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e .            # add [dev] for pytest and ruff
export DATABASE_URL=postgresql://syrenka:syrenka@localhost:5432/syrenka
```

The database must exist and be migrated first — see the root README.

## Commands

```bash
python -m syrenka_ingest stations                      # metro-area stations only
python -m syrenka_ingest stations --all                # all of Poland
python -m syrenka_ingest readings                      # sensors + current readings
python -m syrenka_ingest readings --limit 3 --params PM10 PM2.5
python -m syrenka_ingest nearest --lat 52.2907 --lon 21.0450 --param PM2.5
```

`nearest` prints the station, its distance, the value, when it was measured, and the source. That output is the contract for the API endpoint that follows: never the number alone.

Ingestion is run by hand for now. Scheduling comes with EventBridge and Lambda.

## Configuration

| Variable            | Default                                               | Meaning                               |
| ------------------- | ----------------------------------------------------- | ------------------------------------- |
| `DATABASE_URL`      | `postgresql://syrenka:syrenka@localhost:5432/syrenka` | Postgres connection                   |
| `GIOS_MIN_INTERVAL` | `1.0`                                                 | minimum seconds between GIOŚ requests |
| `LOG_LEVEL`         | `INFO`                                                | logging level                         |

---

## Modules

| File          | Responsibility                                                                                           |
| ------------- | -------------------------------------------------------------------------------------------------------- |
| `gios.py`     | GIOŚ v1 client — rate limiting, retry with backoff, paging, raw capture, tolerant field extraction       |
| `db.py`       | connection handling, raw payload storage, station/sensor upserts, reading inserts, nearest-station query |
| `ingest.py`   | payload → schema normalization, metro-area filtering, timestamp handling                                 |
| `__main__.py` | CLI                                                                                                      |

---

## The GIOŚ API

The legacy `/pjp-api/rest/*` endpoints were **withdrawn on 30 June 2025**. Everything targets `/pjp-api/v1/rest/*`, which returns JSON-LD with Polish-language wrapper keys and paginated list responses.

| Endpoint                                   | Purpose                                  |
| ------------------------------------------ | ---------------------------------------- |
| `/station/findAll`                         | measurement stations (paged)             |
| `/station/sensors/{stationId}`             | measuring positions at a station         |
| `/data/getData/{sensorId}`                 | current readings for a sensor            |
| `/aqindex/getIndex/{stationId}`            | air quality index for a station          |
| `/archivalData/getDataBySensor/{sensorId}` | historical, by date range or `dayNumber` |

OpenAPI docs: `https://dev.api.gios.gov.pl/pjp-api/swagger-ui/`

### Verify before trusting the parser

Field names in v1 are Polish and were not confirmed against a live response when this was written. `field_of()` matches several candidate spellings per field, diacritic- and case-insensitively, so both v1 and legacy shapes parse — but confirm the real names and tighten:

```bash
curl -s 'https://api.gios.gov.pl/pjp-api/v1/rest/station/findAll?page=0&size=2' \
  | python -m json.tool | head -60
```

Check three things:

1. **Field names** — station id, name, latitude, longitude; sensor id and parameter code.
2. **Paging** — whether responses carry `totalPages`, and the maximum `size`.
3. **The documented rate limit.** `GIOS_MIN_INTERVAL` defaults to 1 second as a conservative guess. If the real limit is much lower — 2 requests per minute has been cited — then full metro coverage needs a proper queue rather than a loop.

Nothing is lost by guessing wrong. Every payload is stored verbatim before parsing:

```sql
SELECT endpoint, fetched_at, jsonb_pretty(payload)
FROM raw_payloads ORDER BY id DESC LIMIT 1;
```

Re-parsing is cheap; re-fetching a measurement you didn't save is impossible.

---

## Rules that apply here

- **Raw first.** Every fetch is written to `raw_payloads` before normalization.
- **Timestamps.** GIOŚ returns local Warsaw time with no offset. `Europe/Warsaw` is attached explicitly and UTC is stored. A silently wrong timezone makes a whole series useless while every row looks correct.
- **Nulls are data.** A missing measurement is stored as `NULL` — a real gap, never dropped, never interpolated at ingest.
- **Readings upsert on conflict.** GIOŚ data is explicitly subject to later revision, so a re-fetch overwrites rather than duplicating.
- **Skip loudly.** A record with missing fields is logged and skipped; one bad row never fails the run.
- **Areas are resolved spatially.** `area_id` is assigned by point-in-polygon against `areas`, and stays `NULL` until boundaries are loaded. A reading is valid without it.
