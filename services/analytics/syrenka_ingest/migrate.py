"""Applying numbered SQL migrations.

Invariant 5: migrations only, no hand-edited schema, ever, including
locally. That rule needs something to enforce it once more than one
migration exists — otherwise applying `0002` to a database means
remembering whether `0001` already ran.

Every applied file is recorded in ``schema_migrations`` with the sha256
of its contents. A file whose checksum changed after it was applied is
refused rather than reapplied: `migrations/AGENTS.md` says migrations
are forward-only, and this is what makes that more than a convention.

Each migration runs inside a single transaction together with its
ledger row, so a failure leaves neither a half-applied schema nor a
misleading ledger. The cost is that no migration may contain a
statement Postgres refuses to run in a transaction block — notably
`CREATE INDEX CONCURRENTLY`.
"""

from __future__ import annotations

import hashlib
import logging
import os
from dataclasses import dataclass
from pathlib import Path

from syrenka_ingest.db import connect

logger = logging.getLogger(__name__)

# services/analytics/syrenka_ingest/migrate.py -> repository root
DEFAULT_MIGRATIONS_DIR = Path(__file__).resolve().parents[3] / "migrations"

LEDGER_DDL = """
CREATE TABLE IF NOT EXISTS schema_migrations (
    version    TEXT PRIMARY KEY,
    sha256     TEXT NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
)
"""


class MigrationError(RuntimeError):
    """A migration cannot be applied safely."""


@dataclass(frozen=True)
class Migration:
    """One numbered ``.sql`` file. ``version`` is its stem, e.g. ``0001_init``."""

    version: str
    path: Path
    sha256: str

    @classmethod
    def from_path(cls, path: Path) -> Migration:
        return cls(
            version=path.stem,
            path=path,
            sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
        )


def migrations_dir(override: str | Path | None = None) -> Path:
    """Where the ``.sql`` files live.

    Resolution order: explicit argument, ``MIGRATIONS_DIR``, then the
    repository's own ``migrations/`` relative to this file. The overrides
    exist because an installed copy of the package has no repository
    around it.
    """
    if override is not None:
        return Path(override)
    env = os.environ.get("MIGRATIONS_DIR")
    return Path(env) if env else DEFAULT_MIGRATIONS_DIR


def discover(directory: Path) -> list[Migration]:
    """Every migration in ``directory``, ordered by filename."""
    if not directory.is_dir():
        raise MigrationError(f"migrations directory not found: {directory}")
    return [Migration.from_path(p) for p in sorted(directory.glob("*.sql"))]


def pending(discovered: list[Migration], applied: dict[str, str]) -> list[Migration]:
    """Migrations not yet applied, in order.

    ``applied`` maps version to the sha256 recorded when it ran. A
    version already applied under a different checksum means the file was
    edited after the fact, which is refused: the database and the file no
    longer describe the same schema, and reapplying would not fix it.

    A version present in the database but absent from disk is refused
    too — it usually means the wrong directory, and quietly ignoring it
    would let a later migration apply on top of a schema nobody can
    reconstruct.
    """
    on_disk = {m.version for m in discovered}
    for version in sorted(applied.keys() - on_disk):
        raise MigrationError(f"{version} is recorded as applied but is not in the migrations directory")

    result = []
    for migration in discovered:
        recorded = applied.get(migration.version)
        if recorded is None:
            result.append(migration)
        elif recorded != migration.sha256:
            raise MigrationError(
                f"{migration.version} was edited after it was applied "
                f"(recorded {recorded[:12]}, on disk {migration.sha256[:12]}); "
                "migrations are forward-only — add a new one instead"
            )
    return result


def _applied(cur, *, create_ledger: bool) -> dict[str, str]:
    if create_ledger:
        cur.execute(LEDGER_DDL)
    else:
        cur.execute(
            """
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public' AND table_name = 'schema_migrations'
            """
        )
        if cur.fetchone() is None:
            return {}
    cur.execute("SELECT version, sha256 FROM schema_migrations")
    return {version: sha256 for version, sha256 in cur.fetchall()}


def _execute_sql(cur, sql: str) -> None:
    """Run a migration file and drain any result sets it leaves behind.

    ``0001_init.sql`` ends on ``SELECT create_hypertable(...)``. Leaving that
    result unread makes the ledger ``INSERT`` on the same cursor fail.
    """
    cur.execute(sql)
    while True:
        if cur.description is not None:
            cur.fetchall()
        if not cur.nextset():
            break


def run(dry_run: bool = False, directory: str | Path | None = None) -> None:
    """Apply every pending migration, oldest first."""
    resolved = migrations_dir(directory)
    discovered = discover(resolved)

    with connect() as conn:
        with conn.cursor() as cur:
            outstanding = pending(discovered, _applied(cur, create_ledger=not dry_run))
        conn.commit()

        if not outstanding:
            logger.info("schema up to date: %d migration(s) applied, 0 pending", len(discovered))
            return

        if dry_run:
            for migration in outstanding:
                logger.info("pending: %s", migration.version)
            logger.info("%d migration(s) pending, none applied (dry run)", len(outstanding))
            return

        for migration in outstanding:
            with conn.cursor() as cur:
                _execute_sql(cur, migration.path.read_text())
                cur.execute(
                    "INSERT INTO schema_migrations (version, sha256) VALUES (%s, %s)",
                    (migration.version, migration.sha256),
                )
            conn.commit()
            logger.info("applied %s", migration.version)

        logger.info("%d migration(s) applied", len(outstanding))
