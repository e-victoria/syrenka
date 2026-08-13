# syrenka-ingest

Data ingestion, normalization and analysis. Python owns everything on this side of the boundary: it has no public routes, and the frontend never talks to it. pandas and numpy throughout, plain psycopg, no ORM.

---

## Status

**Not implemented.** This directory contains conventions only. Nothing here runs yet.

---

## Planned first

Three CLI subcommands, each runnable by hand long before anything is scheduled:

```bash
python -m syrenka_ingest areas     # TERYT-keyed boundaries, Warsaw districts + metro gminas
python -m syrenka_ingest places    # OSM via Overpass — playgrounds, parks, museums, libraries…
python -m syrenka_ingest trees     # Warsaw tree crowns / Baza Zieleni
```

Manual first, scheduled second. Scheduling arrives much later, once something user-facing depends on the data — an unread pipeline is speculative infrastructure.

Weather, statistical context and prices follow, each one going through the checklist below.

## Configuration

| Variable       | Default                                               | Meaning             |
| -------------- | ----------------------------------------------------- | ------------------- |
| `DATABASE_URL` | `postgresql://syrenka:syrenka@localhost:5432/syrenka` | Postgres connection |
| `LOG_LEVEL`    | `INFO`                                                | logging level       |

Per-source variables (rate limits, API keys) are documented when that source lands.

---

## Rules that apply here

- **Raw first.** Every fetch is written to `raw_payloads` before normalization. Re-parsing is cheap; re-fetching a measurement you didn't save is impossible.
- **Timestamps.** Attach the source's timezone explicitly, store UTC. A silently wrong timezone makes a whole series useless while every row looks correct.
- **Nulls are data.** A missing value is a real gap, stored as `NULL`, never dropped, never interpolated at ingest.
- **Upsert on conflict** where a source revises its own data, rather than duplicating.
- **Skip loudly.** A record with missing fields is logged and skipped; one bad row never fails the run.
- **Diff, never truncate-and-reload** — OSM especially. Manual curation must survive the next import.
- **Areas resolve spatially.** `area_id` is assigned by point-in-polygon against `areas`, and stays `NULL` where boundaries don't reach. A record is valid without it.
- **Estimates are labelled** — interpolation, derived scores, extrapolation — never silently substituted for an observation.

## Adding a data source

1. **Probe before writing.** `curl` two records and read them. Confirm real field names, paging shape, documented rate limit.
2. **Migration first** — new tables in `migrations/`. Anything located gets `area_id` and geometry; time series get a hypertable.
3. **Client module** — rate limiting, retry with backoff on 429/5xx, paging; returns payload plus URL and status so the caller can store it verbatim.
4. **Normalization** — store raw, then parse, skip and log incomplete records, attach timezone explicitly.
5. **CLI subcommand** — runnable by hand.
6. **Test against a stored payload**, including a null-value case.

Only then schedule it, with retries, a DLQ and a failure alarm. If nothing user-facing consumes the data yet, stop before scheduling.

---

## Appendix — source research

Notes gathered ahead of implementation. Not scheduled, not written.

### GIOŚ (air quality)

Air quality is **not** in the current build order. This is kept because the research is done and the finding is time-sensitive.

The legacy `/pjp-api/rest/*` endpoints were **withdrawn on 30 June 2025**. Anything built must target `/pjp-api/v1/rest/*`, which returns JSON-LD with Polish-language wrapper keys and paginated list responses.

| Endpoint                                   | Purpose                                  |
| ------------------------------------------ | ---------------------------------------- |
| `/station/findAll`                         | measurement stations (paged)             |
| `/station/sensors/{stationId}`             | measuring positions at a station         |
| `/data/getData/{sensorId}`                 | current readings for a sensor            |
| `/aqindex/getIndex/{stationId}`            | air quality index for a station          |
| `/archivalData/getDataBySensor/{sensorId}` | historical, by date range or `dayNumber` |

OpenAPI docs: `https://dev.api.gios.gov.pl/pjp-api/swagger-ui/`

Three things to confirm against a live response before writing a parser: real field names (they are Polish, and unconfirmed here), paging shape and maximum page size, and the documented rate limit — 2 requests per minute has been cited, which would mean full metro coverage needs a queue rather than a loop.

GIOŚ returns local Warsaw time with no offset, and its data is explicitly unverified and subject to later revision — which is why readings would upsert rather than duplicate, and why the app must say so in the UI.
