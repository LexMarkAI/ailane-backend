"""Velocity sub-score computation for the ACEI engine.

Velocity measures how quickly a regulation is moving through the
pipeline and how urgently it demands attention. Returns a multiplier.
"""

from __future__ import annotations

import math

from .models import VelocityInput


def compute_velocity(inp: VelocityInput) -> float:
    """Return a velocity multiplier in the range [0.1, 3.0].

    Components:
    - Urgency from deadline: sigmoid curve based on days remaining.
      Closer deadlines produce a higher multiplier.
    - Amendment frequency: frequent changes signal active regulatory interest.
    - Consultation stage: final rules score higher than proposals.
    """
    # Time urgency: sigmoid-like curve, peaks near deadline
    if inp.days_to_effective is not None and inp.days_to_effective > 0:
        time_factor = 1.0 / (1.0 + math.exp((inp.days_to_effective - 180) / 60))
    else:
        time_factor = 0.5  # No deadline known -> neutral

    # Amendment activity: normalise 0-10 to 0-1
    amendment_factor = inp.amendment_frequency / 10.0

    # Consultation stage: 0 (proposal) to 1 (final)
    stage_factor = inp.consultation_stage

    # Combine into multiplier: base 1.0 + adjustments
    raw = 1.0 + (time_factor * 0.8) + (amendment_factor * 0.6) + (stage_factor * 0.6)

    return min(max(round(raw, 3), 0.1), 3.0)
