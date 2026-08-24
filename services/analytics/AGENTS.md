# Data & ingestion — services/analytics

Root `AGENTS.md` applies. These add to it.

## Honesty

- **Never present a stale reading as current.** Measurement time, station distance and source accompany every value that leaves this layer.
- **GIOŚ data is unverified and subject to later revision** — the app says so in the UI. This is why readings upsert on conflict rather than duplicating.
- **Nulls are data.** A missing measurement is a real gap, stored as `NULL`, never dropped and never interpolated at ingest.
- **Estimates are labelled** — spatial interpolation, derived scores, sparse-price extrapolation — never silently substituted for a measurement.
- **Derived indices are this project's model, never an official statistic.** Weights published and user-adjustable.
- **Coverage travels with the value.** For prices: "3 prices, newest 9 days old," as prominent as the number.

## Ingestion

- **Raw first.** Every fetch is written to `raw_payloads.body` as the exact response bytes, with `content_type`, `content_encoding` and a sha256 of those bytes, before parsing — that table, not S3, is the archive (invariant 4). `payload_json` is filled only when the body is JSON, and is never what re-parsing reads from. Re-parsing is cheap; re-fetching a measurement you didn't save is impossible.
- **Timestamps.** GIOŚ returns local Warsaw time with no offset. Attach `Europe/Warsaw` explicitly, store UTC. A silently wrong timezone makes an entire series useless while every row looks fine.
- **Respect upstream limits.** Rate limiting is client-side via `GIOS_MIN_INTERVAL`. GIOŚ documents 6000 requests per minute across all its interfaces combined — a shared ceiling, not an allowance, so pace well under it. Every ingestion path needs retries, a DLQ and an alarm on failure.
- **Skip loudly.** A record with missing fields is logged and skipped. One bad row never fails a run.
- **Parsers tolerate field-name variation.** Match candidate spellings rather than hardcoding one; upstream APIs rename things.
- **OSM ingestion diffs**, never truncate-and-reload. Manual curation must survive the next import.
- **Areas resolve spatially** — `area_id` is `resolve_area_id(geom)`: the smallest containing administrative area (`city` / `district` / `gmina`). `NULL` until boundaries load, and a reading is valid without it. Green areas are never assigned as `area_id`; they are queried with `ST_Intersects` / `ST_Covers` against `kind = 'green_area'`.
- **Boundaries come from PRG, green areas from OSM.** Districts and gminas are TERYT-keyed and load from PRG; green areas have no TERYT and load from OSM relations, keyed by `(source, source_id)`. Both land in `areas`, distinguished by `kind` — see [`docs/sources/prg.md`](../../docs/sources/prg.md). Downstream uses `kind`, not the loader name; a Warsaw dzielnica and a metro gmina are treated identically.

## Attribution

A legal requirement, and it belongs in the app, not only in docs. GIOŚ: CC BY 4.0, source indicated clearly and visibly. OSM: ODbL. IMGW/Open-Meteo, Warsaw open data, GUS BDL: per provider terms.

## Conventions

Plain psycopg, no ORM. `ruff`, line length 110. Structured logs; runs log source, record counts, failures. Normalization, unit conversion and index-band mapping get tests, with fixtures built from stored raw payloads.

## Adding a new data source

1. **Probe before writing.** `curl` two records and read them. Confirm real field names, paging shape, documented rate limit.
2. **Migration first** — new tables in `migrations/`. Time series get a hypertable; anything located gets `area_id` and geometry.
3. **Register the provider in `sources`** before the first write to `raw_payloads` — `raw_payloads.source` is `NOT NULL REFERENCES sources (name)`, and there is no seed migration for it. The first ingestion run for a source is responsible for its own `sources` row.
4. **Client module** — rate limiting, retry with backoff on 429/5xx, paging, returning payload plus URL and status so the caller can store it verbatim.
5. **Normalization** in `ingest.py` — store raw, then parse, skip and log incomplete records, attach timezone explicitly.
6. **CLI subcommand** — runnable by hand before it is ever scheduled. Manual first, scheduled second.
7. **Test against a stored payload**, including a null-value case.

Only then schedule it, with retries, a DLQ and a failure alarm. If nothing user-facing consumes the data yet, stop before scheduling — an unread pipeline is speculative infrastructure.
