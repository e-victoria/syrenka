# Syrenka

A practical, trilingual companion for exploring Warsaw and its metro area.

It answers _what's around me_ and _what should we do today_ — where to take the kids this afternoon, which park, what's growing on that street, how the city is changing — from real geographic, environmental and public data.

**Not** a dashboard of open data. The product is judged on whether it helps someone today.

---

## Status

**Planning complete, implementation not started.** There is no code in this repository yet — no migrations, no services, no application. What exists is the product direction, the settled stack, and a version-by-version build plan.

Next: the first milestone — an interactive map showing real places from public data.

---

## Direction

The project is built in versions, each shipping something a person can actually use.

It starts with **exploration**: a map of parks, playgrounds, museums, libraries and trees across Warsaw and the metro towns, with search, categories, place detail and what's nearby.

From there it grows into **suggestions** — *what should we do today* — combining weather, distance and how well a place suits the people going, always showing why something was suggested. Then **routes**: a ninety-minute family adventure rather than a single pin.

The slower-moving layers come later — statistical context on how districts are changing, price data, and personalization. Natural-language interaction comes last, as an interface over the engine rather than a source of truth.

Detailed feature and version plans are kept locally, outside this repository.

---

## Architecture

```
Angular PWA  →  Nest.js API  →  PostgreSQL + PostGIS
                     │              (+ TimescaleDB, Redis — when needed)
                     └──internal──► Python service (no public routes)
                                    Python batch jobs → ingestion
```

Nest is the only public API. Python owns ingestion, transformation and computation with pandas and numpy, and is never exposed directly. PostGIS is present from the first migration, because "what's near me" is a spatial query. TimescaleDB is an extension on the same Postgres — so that when time series arrive, a time-series query can join against geometry in a single statement.

```
migrations/            numbered SQL migrations
services/analytics/    Python: ingestion, normalization, analysis
apps/api/              Nest.js — the public API
apps/web/              Angular PWA
docs/                  conventions, roles
```

Working rules, invariants and conventions live in [`AGENTS.md`](AGENTS.md).

---

## Principles

- **Practical over encyclopedic** — answer "what do I do right now."
- **Data-informed** — real geographic and environmental data, not vibes.
- **Local and specific** — individual playgrounds, parks, trees and streets, not categories.
- **Honest about data** — every value carries when it was observed, its source, and what produced it. Never a stale reading presented as current. Derived scores ship with their weights, or they don't ship.
- **Respectful of attention** — suggest, never nag; every proactive suggestion controllable.
- **Works offline where it matters; privacy-respecting.**

**Scope:** Warsaw's 18 districts plus the metro towns people commute from — Ząbki, Marki, Piaseczno, Legionowo, Pruszków, Ożarów, Otwock, Józefów and similar — and the big green areas at the edges. Location is modelled as a hierarchy; "district" never means Warsaw-only.

**Languages:** English, Russian and Polish from day one. No hardcoded strings.

**Health boundary:** environmental features relay official guidance thresholds. They do not give personal medical advice.

**Non-goals:** no payments or booking, no social network, no cities beyond the Warsaw metro area.

---

## Data sources and attribution

Reusing public-sector data carries an attribution obligation. Sources must be indicated clearly and visibly in the app itself, not only here.

| Source                                           | Used for                                       | Stage         | Terms                                                                    |
| ------------------------------------------------ | ---------------------------------------------- | ------------- | ------------------------------------------------------------------------ |
| **OpenStreetMap** contributors                   | playgrounds, parks, amenities, shops, trails   | first         | ODbL — attribution required                                              |
| **Warsaw open data** (mapa.um.warszawa.pl)       | green space, tree crowns, municipal facilities | first         | per portal terms                                                         |
| **PRG / GUS**                                    | area boundaries, TERYT codes                   | first         | per provider terms                                                       |
| **IMGW** / Open-Meteo                            | weather and forecast                           | with scoring  | per provider terms                                                       |
| **GUS BDL**                                      | demographic and statistical context            | later         | per GUS terms                                                            |
| **GIOŚ** — Główny Inspektorat Ochrony Środowiska | air quality measurements and index             | not scheduled | CC BY 4.0; attribution required. Data is unverified and subject to later revision — the app must state this |

Derived indices — neighbourhood comparison, comfort score, place scores — are this project's own analytical models. They are never presented as official statistics, and their weights are published and user-adjustable.
