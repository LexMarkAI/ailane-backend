"""Mitigation credit computation for the ACEI engine.

Mitigation reflects an organisation's existing controls, monitoring,
and response capabilities. It produces a 0-1 reduction factor that
lowers the adjusted ACEI score.
"""

from __future__ import annotations

from .models import MitigationInput

WEIGHTS = {
    "controls_in_place": 0.45,
    "monitoring_coverage": 0.30,
    "response_capability": 0.25,
}

# Maximum possible mitigation credit (cap at 70% reduction)
MAX_CREDIT = 0.70


def compute_mitigation(inp: MitigationInput) -> float:
    """Return a mitigation credit in the range [0, MAX_CREDIT].

    A score of 0 means no mitigation benefit; MAX_CREDIT means
    the organisation's controls reduce exposure by up to 70%.
    """
    raw = (
        inp.controls_in_place * WEIGHTS["controls_in_place"]
        + inp.monitoring_coverage * WEIGHTS["monitoring_coverage"]
        + inp.response_capability * WEIGHTS["response_capability"]
    )
    # Normalise 0-10 weighted score into 0-1, then cap
    credit = (raw / 10.0) * MAX_CREDIT
    return min(max(credit, 0.0), MAX_CREDIT)
