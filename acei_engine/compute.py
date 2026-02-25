"""Core ACEI score computation engine.

Orchestrates impact, likelihood, velocity, and mitigation sub-scores
into a single normalised 0-100 ACEI score with a letter grade.
"""

from __future__ import annotations

from datetime import datetime, timezone

from .impact import compute_impact
from .likelihood import compute_likelihood
from .velocity import compute_velocity
from .mitigation import compute_mitigation
from .normalise import normalise_to_100, score_to_grade
from .models import ACEIInput, ACEIScore

ACEI_VERSION = "v1.0.0"


def compute_acei(inp: ACEIInput) -> ACEIScore:
    """Run the full ACEI pipeline and return a scored result.

    Pipeline:
        1. Impact score        (0-10)
        2. Likelihood score    (0-10)
        3. Raw score           = impact x likelihood  (0-100)
        4. Velocity multiplier (0.1-3.0)
        5. Adjusted score      = raw x velocity
        6. Mitigation credit   (0-1 reduction)
        7. Final score         = normalise(adjusted x (1 - mitigation))  -> 0-100
        8. Grade               = letter grade from final score
    """
    impact = compute_impact(inp.impact)
    likelihood = compute_likelihood(inp.likelihood)

    raw = impact * likelihood  # 0-100

    velocity = compute_velocity(inp.velocity)
    adjusted = raw * velocity

    mitigation = compute_mitigation(inp.mitigation) if inp.mitigation else 0.0
    after_mitigation = adjusted * (1.0 - mitigation)

    final = normalise_to_100(after_mitigation, max_theoretical=300.0)
    grade = score_to_grade(final)

    return ACEIScore(
        organization_id=inp.organization_id,
        risk_category=inp.risk_category,
        jurisdiction=inp.jurisdiction,
        label=inp.label,
        impact_score=round(impact, 2),
        likelihood_score=round(likelihood, 2),
        velocity_multiplier=round(velocity, 2),
        raw_score=round(raw, 2),
        adjusted_score=round(adjusted, 2),
        mitigation_credit=round(mitigation, 4),
        final_score=round(final, 2),
        grade=grade,
        version=ACEI_VERSION,
        computed_at=datetime.now(timezone.utc),
    )


def compute_batch(inputs: list[ACEIInput]) -> list[ACEIScore]:
    """Score multiple ACEI inputs and return results."""
    return [compute_acei(inp) for inp in inputs]
