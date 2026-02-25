"""Scraper for the US Federal Register public API.

Targets final rules, proposed rules, and notices from agencies
relevant to financial-services compliance (SEC, CFTC, FDIC, OCC, Fed).
"""

from __future__ import annotations

import logging
from datetime import datetime, timezone
from typing import Any

from .base import BaseScraper

logger = logging.getLogger(__name__)

FR_API_BASE = "https://www.federalregister.gov/api/v1"

# Agencies whose rulemaking feeds into ACEI scoring
TARGET_AGENCIES = [
    "securities-and-exchange-commission",
    "commodity-futures-trading-commission",
    "federal-deposit-insurance-corporation",
    "comptroller-of-the-currency",
    "federal-reserve-system",
    "consumer-financial-protection-bureau",
    "financial-crimes-enforcement-network",
]

DOCUMENT_TYPES = ["Rule", "Proposed Rule", "Notice"]


class FederalRegisterScraper(BaseScraper):
    """Pull regulatory documents from the Federal Register API."""

    source_name = "federal_register"

    def _fetch_items(self, *, limit: int = 50) -> list[dict[str, Any]]:
        """Fetch recent documents from the Federal Register API."""
        params: dict[str, Any] = {
            "per_page": min(limit, 200),
            "order": "newest",
            "conditions[type][]": DOCUMENT_TYPES,
            "conditions[agencies][]": TARGET_AGENCIES,
            "fields[]": [
                "title",
                "abstract",
                "document_number",
                "type",
                "agencies",
                "publication_date",
                "html_url",
                "pdf_url",
                "citation",
                "regulation_id_numbers",
            ],
        }
        resp = self.http.get(f"{FR_API_BASE}/documents.json", params=params)
        resp.raise_for_status()
        data = resp.json()
        results = data.get("results", [])
        logger.info(
            "Federal Register returned %d documents (count=%s)",
            len(results),
            data.get("count"),
        )
        return results

    def _normalise(self, raw: dict[str, Any]) -> dict[str, Any]:
        agencies = raw.get("agencies", [])
        agency_names = [a.get("name", "") for a in agencies if a.get("name")]

        rin_numbers = raw.get("regulation_id_numbers", [])
        rin_str = ", ".join(r.get("id", "") for r in rin_numbers) if rin_numbers else ""

        summary_parts = []
        if raw.get("type"):
            summary_parts.append(f"[{raw['type']}]")
        if agency_names:
            summary_parts.append(" / ".join(agency_names))
        if raw.get("abstract"):
            summary_parts.append(raw["abstract"][:1500])
        if rin_str:
            summary_parts.append(f"RIN: {rin_str}")
        summary = " — ".join(summary_parts)

        return {
            "title": (raw.get("title") or "Federal Register Document")[:500],
            "summary": summary[:2000],
            "jurisdiction": "US-FEDERAL",
            "source_url": raw.get("html_url", ""),
            "published_at": raw.get("publication_date")
            or datetime.now(timezone.utc).isoformat(),
            "content_hash": self.content_hash(
                f"{raw.get('document_number', '')}{raw.get('title', '')}"
            ),
        }
