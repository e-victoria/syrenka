"""Database connection handling.

Plain psycopg, no ORM (services/analytics/AGENTS.md). ``psycopg`` is
imported lazily inside :func:`connect` so that commands which never
touch the database — ``--help``, argument parsing — don't require
libpq to be installed.
"""

from __future__ import annotations

import os

DEFAULT_DATABASE_URL = "postgresql://syrenka:syrenka@localhost:5432/syrenka"


def database_url() -> str:
    """Resolve the connection string, defaulting to local Docker Compose."""
    return os.environ.get("DATABASE_URL", DEFAULT_DATABASE_URL)


def connect():
    """Open a new connection to Postgres using ``DATABASE_URL``."""
    import psycopg

    return psycopg.connect(database_url())
