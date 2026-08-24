# Migrations

Root `AGENTS.md` applies. These add to it.

- **Numbered, ordered, forward-only.** Never edit a migration that has been applied anywhere but your own laptop. Add a new one.
- **No hand-edited schema**, ever, including locally. If the local database drifted, recreate it from migrations.
- **Location is a hierarchy.** Anything with a place references `areas.id` as `area_id` — the smallest containing administrative area (`city` / `district` / `gmina`), via `resolve_area_id`. `green_area` rows are overlays queried by geometry; they are never stored as `area_id`. Never a district name string, never a column that assumes Warsaw. Population is not an `areas` column; it arrives in V5 as `indicator_values`.
- **Geometry is stored in EPSG:2180, served in EPSG:4326.** Every stored geometry column is 2180 (PUWG 1992), Poland's official planar system, for correct distance and area math. Anything crossing the public API boundary is 4326, transformed in a `*_web` view — `ST_Transform` is STABLE, not IMMUTABLE, so it cannot back a generated column. The API transforms caller coordinates into 2180 before `ST_DWithin`, never the reverse.
- **Honesty fields are columns.** Any measurement or price table carries its `measured_at`/observation time, its `source`, and the identifier of what produced it. A table that stores a bare value is wrong. `raw_payloads.body` is `BYTEA NOT NULL` with a mandatory sha256 of those bytes; `payload_json` is an optional parse, never the archive. `areas` rows carry `source`, `source_id`, and seen-at timestamps; administrative kinds require TERYT, green areas forbid it.
- **Time series are hypertables** with an explicit chunk interval, created in the same migration as the table. `raw_payloads` is the only one until real measurements exist in V2 — the extension being enabled is not a reason to reach for it.
- **Nulls are meaningful** — don't add `NOT NULL` to a measurement column to make a query simpler. The gap is data.
- **One transaction per migration.** The runner (`services/analytics/syrenka_ingest/migrate.py`) applies each file and its ledger row together in a single transaction, so a migration may not contain a statement Postgres refuses inside a transaction block — notably `CREATE INDEX CONCURRENTLY`.
