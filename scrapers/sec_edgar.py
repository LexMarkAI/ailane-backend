"""Scraper for SEC EDGAR full-text search (EFTS) API.

Pulls recent regulatory filings, rule proposals, and final rules
published by the SEC that may affect ACEI scoring.
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from .base import BaseScraper

logger = logging.getLogger(__name__)

EFTS_URL = "https://efts.sec.gov/LATEST/search-index"
FULL_TEXT_SEARCH_URL = "https://efts.sec.gov/LATEST/search-index"

# SEC filing categories relevant to compliance/regulation
RELEVANT_FORMS = ["RIN", "RULE-FINAL", "RULE-PROPOSAL", "S7", "34-"]


class SECEdgarScraper(BaseScraper):
    """Pull regulatory-relevant filings from the SEC EDGAR EFTS API."""

    source_name = "sec_edgar"

    def _fetch_items(self, *, limit: int = 50) -> list[dict[str, Any]]:
        """Query the SEC EDGAR full-text search API for recent regulatory filings."""
        params = {
            "q": "regulation OR compliance OR rule proposal",
            "dateRange": "custom",
            "category": "form-type",
            "startdt": "2025-01-01",
            "enddt": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
            "forms": "RULE",
            "from": 0,
            "size": min(limit, 50),
        }
        resp = self.http.get(
            "https://efts.sec.gov/LATEST/search-index",
            params=params,
        )
        resp.raise_for_status()
        data = resp.json()
        hits = data.get("hits", {}).get("hits", [])
        logger.info("SEC EDGAR returned %d hits", len(hits))
        return hits

    def _normalise(self, raw: dict[str, Any]) -> dict[str, Any]:
        source = raw.get("_source", raw)
        title = source.get("display_names", [source.get("file_description", "")])[0] if source.get("display_names") else source.get("file_description", "SEC Filing")
        file_date = source.get("file_date", "")
        filing_url = f"https://www.sec.gov/Archives/edgar/data/{source.get('entity_id', '')}/{source.get('file_name', '')}"

        summary_parts = []
        if source.get("form_type"):
            summary_parts.append(f"Form: {source['form_type']}")
        if source.get("entity_name"):
            summary_parts.append(f"Entity: {source['entity_name']}")
        if source.get("file_description"):
            summary_parts.append(source["file_description"])
        summary = " | ".join(summary_parts) or title

        return {
            "title": title[:500],
            "summary": summary[:2000],
            "jurisdiction": "US-SEC",
            "source_url": filing_url,
            "published_at": file_date or datetime.now(timezone.utc).isoformat(),
            "content_hash": self.content_hash(f"{title}{file_date}{filing_url}"),
        }
