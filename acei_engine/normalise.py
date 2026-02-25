"""Normalisation and grading utilities for ACEI scores."""

from __future__ import annotations


def normalise_to_100(value: float, *, max_theoretical: float = 300.0) -> float:
    """Clamp and scale a raw value into the 0-100 range.

    Args:
        value: The raw score to normalise.
        max_theoretical: The theoretical maximum of the raw score
                         (impact_max * likelihood_max * velocity_max = 10*10*3 = 300).
    """
    ratio = value / max_theoretical
    score = ratio * 100.0
    return min(max(score, 0.0), 100.0)


def score_to_grade(score: float) -> str:
    """Map a 0-100 ACEI score to a letter grade.

    Grading scale (higher score = higher risk):
        A  (0-20)   Minimal exposure
        B  (21-40)  Low exposure
        C  (41-60)  Moderate exposure
        D  (61-80)  High exposure
        F  (81-100) Critical exposure
    """
    if score <= 20:
        return "A"
    if score <= 40:
        return "B"
    if score <= 60:
        return "C"
    if score <= 80:
        return "D"
    return "F"
