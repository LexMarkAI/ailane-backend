"""Likelihood sub-score computation for the ACEI engine.

Likelihood estimates the probability that a regulatory event will
impact the organisation. Industry readiness acts as a dampener.
"""

from __future__ import annotations

from .models import LikelihoodInput

WEIGHTS = {
    "enforcement_history": 0.30,
    "regulatory_momentum": 0.35,
    "political_support": 0.20,
    "industry_readiness": 0.15,
}


def compute_likelihood(inp: LikelihoodInput) -> float:
    """Return a likelihood score in the range [0, 10].

    ``industry_readiness`` is inverted: a high readiness value *reduces*
    the overall likelihood (the industry is prepared, so less exposure).
    """
    inverted_readiness = 10.0 - inp.industry_readiness

    score = (
        inp.enforcement_history * WEIGHTS["enforcement_history"]
        + inp.regulatory_momentum * WEIGHTS["regulatory_momentum"]
        + inp.political_support * WEIGHTS["political_support"]
        + inverted_readiness * WEIGHTS["industry_readiness"]
    )
    return min(max(score, 0.0), 10.0)
