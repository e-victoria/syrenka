"""CLI entrypoint: ``python -m syrenka_ingest <command>``."""

from __future__ import annotations

import argparse
import logging
import os
import sys

from syrenka_ingest import areas, migrate

LOG_LEVEL = os.environ.get("LOG_LEVEL", "INFO")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="syrenka_ingest",
        description="Data ingestion, normalization and analysis for Syrenka.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    migrate_parser = subparsers.add_parser("migrate", help="apply pending SQL migrations")
    migrate_parser.add_argument(
        "--dry-run", action="store_true", help="list pending migrations without applying them"
    )
    migrate_parser.add_argument(
        "--dir", dest="directory", default=None, help="migrations directory (overrides MIGRATIONS_DIR)"
    )

    subparsers.add_parser("areas", help="load area boundaries into the areas table")

    return parser


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=LOG_LEVEL)

    parser = build_parser()
    args = parser.parse_args(argv)

    if args.command == "migrate":
        try:
            migrate.run(dry_run=args.dry_run, directory=args.directory)
        except migrate.MigrationError as exc:
            logging.getLogger("syrenka_ingest").error("%s", exc)
            return 1
        return 0

    if args.command == "areas":
        areas.load_areas()
        return 0

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
