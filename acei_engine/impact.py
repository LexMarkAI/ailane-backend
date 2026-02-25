"""Impact sub-score computation for the ACEI engine.

Impact measures how severe the consequences of a regulatory event
would be if it materialises. Weighted average of four dimensions.
"""

from __future__ import annotations

from .models import ImpactInput

# Weights must sum to 1.0
WEIGHTS = {
    "regulatory_severity": 0.35,
    "financial_exposure": 0.30,
    "operational_disruption": 0.20,
    "scope_breadth": 0.15,
}


def compute_impact(inp: ImpactInput) -> float:
    """Return a weighted impact score in the range [0, 10]."""
    score = (
        inp.regulatory_severity * WEIGHTS["regulatory_severity"]
        + inp.financial_exposure * WEIGHTS["financial_exposure"]
        + inp.operational_disruption * WEIGHTS["operational_disruption"]
        + inp.scope_breadth * WEIGHTS["scope_breadth"]
    )
    return min(max(score, 0.0), 10.0)
