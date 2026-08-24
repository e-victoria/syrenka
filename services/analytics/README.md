# syrenka-ingest

Data ingestion, normalization and analysis. Python owns everything on this
side of the boundary: no public routes, and the frontend never talks to it.

**Status: scaffold.** The package installs and the CLI runs. No loader is
implemented yet — `areas` logs and exits. Boundary loading is the next piece
of work.

---

## Install

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e .            # add [dev] for pytest and ruff
export DATABASE_URL=postgresql://syrenka:syrenka@localhost:5432/syrenka
```

The database must exist first (`docker compose up -d db` from the root),
then `python -m syrenka_ingest migrate` below brings the schema up to date.

## Commands

| Command                            | Does                                                  | State                                 |
| ----------------------------------- | ------------------------------------------------------ | -------------------------------------- |
| `python -m syrenka_ingest migrate`  | apply pending SQL migrations from `migrations/`        | implemented                            |
| `python -m syrenka_ingest areas`    | load area boundaries and TERYT codes into `areas`      | **not implemented** — logs and exits   |

Ingestion is run by hand. Scheduling comes later, and only once something
user-facing reads the data.

## Configuration

| Variable       | Default                                               | Meaning             |
| -------------- | ----------------------------------------------------- | ------------------- |
| `DATABASE_URL` | `postgresql://syrenka:syrenka@localhost:5432/syrenka` | Postgres connection |
| `LOG_LEVEL`    | `INFO`                                                | logging level       |

## Modules

| File          | Responsibility                                                            |
| ------------- | ------------------------------------------------------------------------- |
| `__main__.py` | CLI entry point                                                           |
| `db.py`       | connection handling; `psycopg` imported lazily so `--help` works without libpq |
| `areas.py`    | area loading (placeholder)                                                |
| `migrate.py`  | applies numbered SQL migrations; records each in `schema_migrations`      |

---

## Rules

Ingestion rules — raw first, explicit timezones, nulls as data, skip loudly,
spatial area resolution — are in [`AGENTS.md`](AGENTS.md) in this directory.
They are not repeated here, so they can't drift.

## Sources not yet built

Air quality (GIOŚ) belongs to V2, alongside weather. Research notes:
[`docs/sources/gios.md`](../../docs/sources/gios.md). Boundary loading (PRG)
is V1; notes: [`docs/sources/prg.md`](../../docs/sources/prg.md).
