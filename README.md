# Syrenka

**A practical, trilingual daily-life companion for Warsaw and its metro area.**

Syrenka answers *"what do I do right now"* using real environmental, price and geographic data — where to buy a specific item, how prices compare between shops, where to take the kids this afternoon, and what the air is like today.

> **Status: planning and design.** No application code yet.

---

## The idea

There's a version of this that would be a mistake: a website that displays Warsaw's open data. Technically interesting, not useful.

Here the data is the engine, not the product. Air quality, tree canopy and playground locations mean little separately. Joined geographically, they answer a question nobody else answers — *which park should we go to this afternoon.*

Three examples of what that looks like:

> **🌳 Explore trees in Bielany — 8.7/10**
> 2.8 km walk · ~60–90 min · 23°C · 🛝 playground halfway · 🚻 toilets
> *Why today:* comfortable weather, good shade on the route, air quality is good in Bielany right now.

> **Where do I buy fresh coriander?** — a specific item, not a category. Near Ząbki, open now, Sunday trading rules handled, including the Asian and Ukrainian grocers a chain-only search would miss.

> **Your shopping list, priced nearby** — Store B costs 2.70 zł more than Store A and saves you 15 minutes. Not a budgeting app; an optimisation problem with geography in it.

---

## Scope

**Geography.** Warsaw's 18 districts plus the surrounding gminas people actually live in and commute from — Ząbki, Marki, Raszyn, Piaseczno, Legionowo, Pruszków, Otwock and their neighbours — plus the green areas at the edges. The metro towns are first-class: anything that works for Mokotów must work for Raszyn.

**Languages.** Full trilingual — English, Russian, Polish — from day one. No hardcoded text anywhere.

**Non-goals.** No payments or booking, no social network, and no expansion to other Polish cities.

---

## Principles

- **Practical over encyclopedic** — judged on whether it helps someone today.
- **Honest about data** — every reading shows its measurement time, source and station distance. GIOŚ data is unverified and the app says so. Sparse price data gets the same treatment: *"3 prices, newest 9 days old."*
- **Explainable over clever** — recommendations are rules-based with published weights. A recommendation you can't explain is one nobody trusts.
- **Local and specific** — individual shops, playgrounds and streets, not categories.
- **Respectful of attention** — suggest, never nag; every proactive feature ships with its off switch.

Air-quality features relay official index bands and official guidance. They don't give medical advice.

---

## Features

**Core — daily life**

| Area | |
|---|---|
| **Environment** | live air quality with official index bands, historical charts and seasonal patterns, district ranking, weather as a decision variable, tree cover and canopy scoring, forests and green escapes |
| **Shopping & prices** | "where do I buy X?" for specific items across shops, bazary and international grocers · shopping list → basket comparison per branch · cost-versus-distance recommendations |
| **Eating out** | by craving and cuisine, filtered by price, area, open-now, kid-friendliness, staff language |
| **Family & outdoors** | parks, playgrounds and rainy-day options, cross-filtered by air quality and tree cover · "what should we do today?" with explicit reasons |
| **Essentials** | night pharmacies, ATMs, post, emergency info, ZTM tickets and journey planning |
| **Newcomer kit** | PESEL, karta pobytu, meldunek, NFZ, banking, housing — each article carrying a "last verified" date |

**Discovery layer** (on by default, removable): a sourced historical guide and events.

**After V1:** receipt scanning, air-quality alerts, route generation, image recognition, nature quests, GUS statistical context.

---

## Stack

```
Angular PWA → Nest.js API → PostgreSQL (PostGIS + TimescaleDB) · Redis
                    ↕
          Python analytics (internal, no public routes)
                    ↑
     GIOŚ · IMGW · OSM · Warsaw open data · GUS BDL
```

Angular 22 (signals, zoneless) · Nest.js as the only public API · Python for ingestion, analysis and computation · PostgreSQL with PostGIS and TimescaleDB in one instance · Redis · AWS (Lambda, EventBridge, Fargate, RDS, S3, Cognito).

Two decisions worth knowing:

**Python has no public surface.** It owns ingestion, transformation and computation; Nest owns everything user-facing and the database schema. Nest never proxies a raw Python response to a client.

**PostGIS and TimescaleDB share one database.** The product's distinctive claim — *parks near me, good air right now, shaded* — is one SQL query joining time-series readings to geometry. Splitting the time series into a separate store would turn that into application-level orchestration.

Detail: [`docs/architecture/technical-stack.md`](docs/architecture/technical-stack.md), authoritative on any stack question.

---

## Roadmap

V1 is broad — all core areas ship together, with two internal milestones so the app is usable well before it's complete.

| | Phase |
|---|---|
| 0 | Foundation — deployed, empty, trilingual app with a map and a pipeline |
| 1 | Environment engine — air quality and weather |
| 2 | Places and shopping |
| | 🏁 *Alpha* |
| 3 | Family, outdoors and greenery — the cross-filter |
| 4 | Prices |
| 5 | Newcomer kit, transport, discovery |
| 6 | Suggestions and insights |
| | 🎉 *V1* |

The order is dependency-driven: Phase 1 builds the ingestion spine, Phase 2 the place layer, Phase 3 joins them. Prices come fourth because it's the one dataset created from nothing. Recommendations come last, because a recommendation engine over thin data produces confident nonsense.

Detail: [`docs/plan/`](docs/plan/).

---

## Repository

```
apps/{web,api,analytics}   Angular · Nest · Python
libs/{contracts,i18n}      shared types · translation catalogs
infra/                     infrastructure as code
db/                        migrations, seed data
docs/                      product, architecture, plan, conventions
AGENTS.md                  instructions for AI coding agents
```

Each fact lives in exactly one document; `docs/architecture/technical-stack.md` wins on stack questions, `docs/product/vision.md` on product ones, ADRs on why.

---

## Working with AI agents

Developed with AI agents in four separated roles — test author, implementer, reviewer, architect. What each role is *not* allowed to see is what makes its output worth having: a test author who has seen the implementation writes tests that pass.

[`AGENTS.md`](AGENTS.md) is the portable source of truth; tool-specific files point at it. **Agents do not write code until explicitly authorised, per task.**

---

## Data sources

GIOŚ (air quality) · IMGW and Open-Meteo (weather) · GUGiK/PRG (boundaries) · OpenStreetMap (places) · Warsaw open data (green space, tree crowns) · GUS BDL (statistics) · ZTM (transport). All public, all requiring attribution, which is honoured in the app and not just here.

Prices have no public source — they start as manual entry and CSV import.

---

*Syrenka* — the mermaid on Warsaw's coat of arms. The interface asks a simple question; underneath sits a geospatial data platform. The user should never have to see that.

**Licence:** not yet chosen. Source data carries its own terms regardless.
