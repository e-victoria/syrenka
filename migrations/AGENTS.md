# Migrations

Root `AGENTS.md` applies. These add to it.

- **Numbered, ordered, forward-only.** Never edit a migration that has been applied anywhere but your own laptop. Add a new one.
- **No hand-edited schema**, ever, including locally. If the local database drifted, recreate it from migrations.
- **Location is a hierarchy.** Anything with a place references `areas.id` and carries PostGIS geometry. Never a district name string, never a column that assumes Warsaw.
- **Honesty fields are columns.** Any measurement or price table carries its `measured_at`/observation time, its `source`, and the identifier of what produced it. A table that stores a bare value is wrong.
- **Time series are hypertables** with an explicit chunk interval, created in the same migration as the table.
- **Nulls are meaningful** — don't add `NOT NULL` to a measurement column to make a query simpler. The gap is data.
