# AGENTS.md

Syrenka — a practical, trilingual (EN/RU/PL) companion for exploring Warsaw and its metro area. Answers _what's around me_ and _what should we do today_: where to take the kids this afternoon, which park, what's growing on that street, how the city is changing. Not a dashboard of open data — it is judged on whether it helps someone today.

Built in versions, each shipping something usable. Exploration and family activities come first — map, places and trees, then weather-aware suggestions, then routes. Statistics, prices and personalization come later; natural-language interaction last. Detailed feature and version plans are kept locally, outside this repository.

## Invariants — breaking these is a rewrite, not a refactor

1. **Location is a hierarchy.** One TERYT-keyed `areas` table; Warsaw districts and metro gminas are the same kind of row. Everything references `area_id`, never a name string. "District" never means Warsaw-only.
2. **Honesty fields are schema.** Every value carries when it was observed, its `source`, and the identifier of whatever produced it — station, sensor, or upstream record. The API never returns a bare number, and never a bare place. Staleness thresholds live server-side.
3. **The Python boundary holds.** Python: ingestion, transformation, computation — no public routes, ever. Nest: everything user-facing, and all user-generated writes. Nest never proxies a raw Python response.
4. **Raw data is kept.** Every external fetch is stored verbatim before normalization.
5. **Migrations only.** No hand-edited schema, ever, including locally.
6. **Translation keys, no hardcoded strings.** In every component, from the first one.

If a task seems to require breaking one, stop and say so.

## Stack

```
Angular PWA → Nest.js API → PostgreSQL + PostGIS
                   │            (+ TimescaleDB, Redis — when needed)
                   └─internal─► Python (FastAPI, internal only) + batch jobs
```

PostGIS is there from the first migration — V1's "what's near me" is a spatial query. Timescale is an extension on the _same_ Postgres, deliberately, so time-series can join geometry in one statement; it arrives with the first real time series. Redis arrives when a query is slow. Angular Material, ngx-translate, Leaflet/MapLibre. Python: pandas, numpy, plain psycopg, no ORM. AWS: Lambda, EventBridge, ECS Fargate, S3, SQS/SNS, Cognito.

Don't add a datastore, framework, queue or hosted service without agreement.

```
migrations/          numbered SQL migrations
services/analytics/  Python ingestion + analysis
apps/api/            Nest.js
apps/web/            Angular
```

## How to work

- **Work one version at a time.** The current version's scope, migrations, endpoints and exit criteria are agreed before work starts, not discovered during it. What comes after it is a direction, not a specification.
- **Build vertically.** Every task ends in something visible — a screen, an endpoint with real data, a job writing real rows. If it doesn't, it's too big; split it.
- **No speculative infrastructure.** Redis when a query is slow. Auth when there's user data. A design system when there's a third screen. The six invariants are the only things built ahead of need.
- **Keep it deployed.** Once there's a screen, it stays reachable from a phone.
- **Boring and explainable.** Rules and published weights over models.
- **Pivoting is fine.** If reality contradicts an assumption, say so rather than forcing the build.
- **Don't write planning documents unasked.** Prefer code, a migration, or a screen.

## Boundaries

- **Geography:** Warsaw's 18 districts, the commuter towns (Ząbki, Marki, Piaseczno, Legionowo, Pruszków, Ożarów, Otwock, Józefów and similar), the big green areas at the edges. No other cities.
- **Health:** relay official air-quality index bands and official guidance. Never personal medical advice, never invented thresholds.
- **Attention:** suggest, never nag. Suggestion controls ship with the suggestion, not after.
- **Non-goals:** no payments or booking, no social network, no other cities.

## Conventions

Area-specific instructions live in nested `AGENTS.md` files, loaded alongside this one when you work in that subtree: `apps/api/`, `apps/web/`, `services/analytics/`, `migrations/`. Commit conventions: `docs/conventions/commits.md`.

## Done means

Migrated, translated (keys present), honest (timestamp/source/coverage carried through), tested where logic is non-trivial, deployable, and visible.
