# Syrenka

A practical, trilingual daily-life companion for Warsaw and its metro area.

It answers _what do I do right now_ — where to buy a specific item, where to eat what you're craving, how prices compare between shops and districts, where to take the kids, and what the air and greenery are like — from real environmental, price and geographic data.

**Not** a dashboard of open data. The product is judged on whether it helps someone today.

---

## Status

Early. Postgres schema exists and the Python ingestion package is scaffolded; no loader is implemented yet. Area boundaries are next, then places. The API and web app follow.

---

## Quickstart

Requires Docker and Python 3.11+.

```bash
# 1. Database — Postgres with PostGIS and TimescaleDB
docker compose up -d db

# 2. Ingestion package
cd services/analytics
python -m venv .venv && source .venv/bin/activate
pip install -e .

cp ../../.env.example ../../.env      # then export, or use direnv
export DATABASE_URL=postgresql://syrenka:syrenka@localhost:5432/syrenka

# 3. Schema — migrations only, never psql by hand
python -m syrenka_ingest migrate --dry-run
python -m syrenka_ingest migrate

python -m syrenka_ingest --help
python -m syrenka_ingest areas     # not implemented yet — logs and exits
```

Every applied migration is recorded in `schema_migrations` with the sha256 of its contents, and a file edited after it ran is refused rather than reapplied. Applying the SQL by hand leaves that ledger empty, so the next `migrate` tries to run `0001` again and fails. If the local schema has drifted, recreate it: `docker compose down -v && docker compose up -d db`, then `migrate` — never insert a ledger row by hand.

No loader writes rows yet. When one does, the fetched response lands as exact bytes in `raw_payloads.body` before anything parses it. Every reading it produces carries its measurement time, its source and the station that produced it — never the number alone. Distance from that station is computed per request and shown alongside. That shape is the contract every later layer preserves.

More detail in [`services/analytics/README.md`](services/analytics/README.md).

---

## Architecture

```
Angular PWA  →  Nest.js API  →  PostgreSQL + PostGIS + TimescaleDB
                     │
                     └──internal──► Python service (no public routes)
                                    Python batch jobs → ingestion
```

Nest is the only public API. Python owns ingestion, transformation and computation, and is never exposed directly. TimescaleDB is an extension on the same Postgres as PostGIS, so a time-series query can join against geometry in a single statement — which is exactly what "parks near me with good air right now" needs. Redis is not in local dev and not in that picture until a query is measurably slow.

```
migrations/            numbered SQL migrations
services/analytics/    Python: ingestion, normalization, analysis
apps/api/              Nest.js — the public API
apps/web/              Angular PWA
docs/                  conventions, roles, source notes
```

Working rules, invariants and conventions live in [`AGENTS.md`](AGENTS.md).

---

## Principles

- **Practical over encyclopedic** — answer "what do I do right now."
- **Data-informed** — real environmental, price and geographic data, not vibes.
- **Local and specific** — individual shops, playgrounds and streets, not categories.
- **Honest about data** — sensor readings have gaps and uncertainty. Measurement time, station distance and source always shown. Never a stale reading presented as current. The same honesty applies to prices, which are sparse and user-contributed: always shown with their date and the shop they came from.
- **Respectful of history** — historical context is sourced fact by fact, never invented to fill a gap, and always secondary: it appears because you stopped to look at something.
- **Respectful of attention** — suggest, never nag; every proactive suggestion controllable.
- **Works offline where it matters; privacy-respecting.**

**Scope:** Warsaw's 18 districts plus the metro towns people commute from — Ząbki, Marki, Piaseczno, Legionowo, Pruszków, Ożarów, Otwock, Józefów and similar — and the big green areas at the edges. Location is modelled as a hierarchy; "district" never means Warsaw-only.

**Languages:** English, Russian and Polish from day one. No hardcoded strings.

**Health boundary:** air quality features relay official guidance thresholds. They do not give personal medical advice.

**Non-goals:** no payments or booking, no social network, no cities beyond the Warsaw metro area.

---

## Data sources and attribution

Reusing public-sector data carries an attribution obligation. Sources must be indicated clearly and visibly in the app itself, not only here.

| Source                                           | Used for                                                                    | Terms                                                                                                          |
| ------------------------------------------------ | ----------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **PRG / GUGiK** — Państwowy Rejestr Granic       | area boundaries and TERYT codes — every `areas` row of kind city, district, gmina | public register; attribution required                                                                          |
| **GIOŚ** — Główny Inspektorat Ochrony Środowiska | air quality measurements and index                                          | CC BY 4.0; source attribution required. Data is unverified and subject to later revision — the app states this |
| **IMGW** / Open-Meteo                            | weather and forecast                                                        | per provider terms                                                                                             |
| **OpenStreetMap** contributors                   | shops, amenities, parks, trails, green areas, transport stops               | ODbL — attribution required                                                                                    |
| **Warsaw open data** (mapa.um.warszawa.pl)       | green space, tree crowns, municipal facilities                              | per portal terms                                                                                               |
| **GUS BDL**                                      | demographic and statistical context                                         | per GUS terms                                                                                                  |
| **User-contributed prices** — manual entry, CSV  | shop prices, basket comparison                                              | not an official source and never presented as one; sparse, and carried with its date and shop                  |

Derived indices — neighbourhood comparison, comfort score, place scores — are this project's own analytical models. They are never presented as official statistics, and their weights are published and user-adjustable.

Historical content is not a dataset and has no provider row above. It is curated text attached to places, trees and buildings; each fact carries its own citation the same way a reading carries its station, and a fact with no citation isn't shown.
