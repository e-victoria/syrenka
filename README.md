# Syrenka

A practical, trilingual daily-life companion for Warsaw and its metro area.

It answers _what do I do right now_ — where to buy a specific item, where to eat what you're craving, how prices compare between shops and districts, where to take the kids, and what the air and greenery are like — from real environmental, price and geographic data.

**Not** a dashboard of open data. The product is judged on whether it helps someone today.

---

## Status

Early. GIOŚ air-quality ingestion writes real readings to Postgres; the API and web app come next.

---

## Quickstart

Requires Docker and Python 3.11+.

```bash
# 1. Database — Postgres with PostGIS and TimescaleDB
docker compose up -d db
docker compose exec -T db psql -U syrenka -d syrenka < migrations/0001_init.sql

# 2. Ingestion
cd services/analytics
python -m venv .venv && source .venv/bin/activate
pip install -e .

cp ../../.env.example ../../.env      # then export, or use direnv
export DATABASE_URL=postgresql://syrenka:syrenka@localhost:5432/syrenka

python -m syrenka_ingest stations                          # metro-area stations
python -m syrenka_ingest readings --limit 3 --params PM10 PM2.5
python -m syrenka_ingest nearest --lat 52.2907 --lon 21.0450   # Ząbki
```

Expected output: a station name, its distance, a PM2.5 value, the time it was measured, and its source. That shape is the contract every later layer preserves — never the number alone.

More detail in [`services/analytics/README.md`](services/analytics/README.md).

---

## Architecture

```
Angular PWA  →  Nest.js API  →  PostgreSQL + PostGIS + TimescaleDB
                     │              Redis
                     └──internal──► Python service (no public routes)
                                    Python batch jobs → ingestion
```

Nest is the only public API. Python owns ingestion, transformation and computation, and is never exposed directly. TimescaleDB is an extension on the same Postgres as PostGIS, so a time-series query can join against geometry in a single statement — which is exactly what "parks near me with good air right now" needs.

```
migrations/            numbered SQL migrations
services/analytics/    Python: ingestion, normalization, analysis
apps/api/              Nest.js — the public API
apps/web/              Angular PWA
docs/                  conventions, roles, skills
```

Working rules, invariants and conventions live in [`AGENTS.md`](AGENTS.md).

---

## Principles

- **Practical over encyclopedic** — answer "what do I do right now."
- **Data-informed** — real environmental, price and transit data, not vibes.
- **Local and specific** — individual shops, playgrounds and streets, not categories.
- **Honest about data** — sensor readings have gaps and uncertainty. Measurement time, station distance and source always shown. Never a stale reading presented as current.
- **Respectful of attention** — suggest, never nag; every proactive suggestion controllable.
- **Works offline where it matters; privacy-respecting.**

**Scope:** Warsaw's 18 districts plus the metro towns people commute from — Ząbki, Marki, Piaseczno, Legionowo, Pruszków, Ożarów, Otwock, Józefów and similar — and the big green areas at the edges. Location is modelled as a hierarchy; "district" never means Warsaw-only.

**Languages:** English, Russian and Polish from day one. No hardcoded strings.

**Health boundary:** air quality features relay official guidance thresholds. They do not give personal medical advice.

**Non-goals:** no payments or booking, no social network, no cities beyond the Warsaw metro area.

---

## Data sources and attribution

Reusing public-sector data carries an attribution obligation. Sources must be indicated clearly and visibly in the app itself, not only here.

| Source                                           | Used for                                       | Terms                                                                                                          |
| ------------------------------------------------ | ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| **GIOŚ** — Główny Inspektorat Ochrony Środowiska | air quality measurements and index             | CC BY 4.0; source attribution required. Data is unverified and subject to later revision — the app states this |
| **IMGW** / Open-Meteo                            | weather and forecast                           | per provider terms                                                                                             |
| **OpenStreetMap** contributors                   | shops, amenities, parks, trails                | ODbL — attribution required                                                                                    |
| **Warsaw open data** (mapa.um.warszawa.pl)       | green space, tree crowns, municipal facilities | per portal terms                                                                                               |
| **GUS BDL**                                      | demographic and statistical context            | per GUS terms                                                                                                  |

Derived indices — neighbourhood comparison, comfort score, place scores — are this project's own analytical models. They are never presented as official statistics, and their weights are published and user-adjustable.
