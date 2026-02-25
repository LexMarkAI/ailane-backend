"""Base scraper with shared logic for all regulatory data sources."""

from __future__ import annotations

import hashlib
import logging
from abc import ABC, abstractmethod
from datetime import datetime, timezone
from typing import Any

import httpx
from supabase import Client

logger = logging.getLogger(__name__)

SCRAPER_RUNS_TABLE = "scraper_runs"
REGULATORY_UPDATES_TABLE = "regulatory_updates"


class BaseScraper(ABC):
    """Abstract base for every regulatory-feed scraper.

    Subclasses implement ``_fetch_items`` to pull raw records from a source
    and ``_normalise`` to map each raw record into the canonical shape that
    the ``regulatory_updates`` table expects.
    """

    source_name: str = "unknown"

    def __init__(self, supabase: Client, *, timeout: float = 30.0) -> None:
        self.sb = supabase
        self.http = httpx.Client(
            timeout=timeout,
            headers={"User-Agent": "Ailane-ACEI-Scraper/1.0"},
            follow_redirects=True,
        )

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------
    def run(self, *, limit: int = 50) -> list[dict[str, Any]]:
        """Execute a full scrape cycle: fetch ➜ deduplicate ➜ store."""
        run_id = self._start_run()
        try:
            raw_items = self._fetch_items(limit=limit)
            normalised = [self._normalise(item) for item in raw_items]
            new_rows = self._deduplicate_and_insert(normalised)
            self._finish_run(run_id, inserted=len(new_rows))
            logger.info(
                "%s: fetched=%d inserted=%d",
                self.source_name,
                len(raw_items),
                len(new_rows),
            )
            return new_rows
        except Exception:
            self._finish_run(run_id, inserted=0, error=True)
            raise

    # ------------------------------------------------------------------
    # Template methods – subclasses MUST implement
    # ------------------------------------------------------------------
    @abstractmethod
    def _fetch_items(self, *, limit: int) -> list[dict[str, Any]]:
        """Return raw items from the upstream source."""

    @abstractmethod
    def _normalise(self, raw: dict[str, Any]) -> dict[str, Any]:
        """Map a raw upstream record into a ``regulatory_updates`` row dict.

        Must return at least:
            title, summary, jurisdiction, source_url, published_at, content_hash
        """

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------
    @staticmethod
    def content_hash(text: str) -> str:
        """SHA-256 hex digest used for deduplication."""
        return hashlib.sha256(text.encode()).hexdigest()

    def _deduplicate_and_insert(
        self, rows: list[dict[str, Any]]
    ) -> list[dict[str, Any]]:
        """Insert rows that don't already exist (by content_hash)."""
        if not rows:
            return []

        hashes = [r["content_hash"] for r in rows]
        existing = (
            self.sb.table(REGULATORY_UPDATES_TABLE)
            .select("content_hash")
            .in_("content_hash", hashes)
            .execute()
        )
        existing_hashes = {r["content_hash"] for r in existing.data}
        new_rows = [r for r in rows if r["content_hash"] not in existing_hashes]
        if new_rows:
            for row in new_rows:
                row["source"] = self.source_name
            self.sb.table(REGULATORY_UPDATES_TABLE).insert(new_rows).execute()
        return new_rows

    def _start_run(self) -> str:
        result = (
            self.sb.table(SCRAPER_RUNS_TABLE)
            .insert(
                {
                    "source": self.source_name,
                    "status": "running",
                    "started_at": datetime.now(timezone.utc).isoformat(),
                }
            )
            .execute()
        )
        return result.data[0]["id"]

    def _finish_run(
        self, run_id: str, *, inserted: int, error: bool = False
    ) -> None:
        self.sb.table(SCRAPER_RUNS_TABLE).update(
            {
                "status": "error" if error else "success",
                "items_inserted": inserted,
                "finished_at": datetime.now(timezone.utc).isoformat(),
            }
        ).eq("id", run_id).execute()
