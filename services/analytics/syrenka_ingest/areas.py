"""Loading logic for the ``areas`` table.

Warsaw's 18 districts and the metro gminas are the same kind of row
here, distinguished only by ``kind`` (AGENTS.md, invariant 1). The
PRG boundary loader and the OSM green-area loader land in later
commits; this module is the entry point they hang off, and the
``areas`` CLI subcommand calls into it.
"""

from __future__ import annotations

import logging

logger = logging.getLogger(__name__)


def load_areas() -> None:
    """Load area boundaries into the ``areas`` table.

    Not implemented yet — the PRG districts/gminas loader and the OSM
    green-area loader are separate, later pieces of work.
    """
    logger.info("area loading is not implemented yet")
