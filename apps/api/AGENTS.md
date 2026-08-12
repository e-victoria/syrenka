# API — apps/api

Root `AGENTS.md` applies. These add to it.

## This is the only public surface

Every client request enters here. The Python service is internal and never routed through the gateway; if a request seems to need Python directly, add an endpoint here instead.

- **Hot paths read precomputed data** from Postgres or Redis. Nest does not call Python to render a chart or a list.
- **Nest calls Python** over the internal network only for computation that genuinely can't be precomputed — a custom basket total, a user-weighted comparison, a recommendation with novel parameters.
- **Never proxy a raw Python response** to the client. Translate it into the API's own contract.
- **All user-generated writes land here** — saved lists, preferences, receipt uploads, alert subscriptions. Python may read them; it does not own them.

## Response contracts

**No endpoint returns a bare measurement.** Any environmental or price value is returned with its observation time, its source, and — for readings — the station identifier and distance from the requested point. A response shaped `{ "pm25": 18 }` is wrong.

Staleness is decided here, not in the client. If a reading is older than the threshold for its parameter, the response says so explicitly rather than leaving the client to compare timestamps.

Derived scores are returned with their weights, or with a reference to the published weights. A score without its basis is not explainable, and an unexplainable score doesn't ship.

## Location

Anything with a place references `area_id`. Never accept or return a district name as an identifier. Endpoints must work identically for a Warsaw district and a metro gmina — if a query only makes sense for Warsaw, the design is wrong.

## Language

Trilingual content is served by key or by negotiated locale, never by hardcoded string. Error messages are translatable — return a code the client can localize, not a rendered English sentence.

## Conventions

DTOs validated at the boundary. Errors are typed and specific; never surface a database error, an upstream HTTP status, or a stack trace. Anything touching auth, ownership or user data gets a test.
