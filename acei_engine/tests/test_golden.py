"""Golden-path tests for the ACEI scoring engine."""

from acei_engine.models import (
    ACEIInput,
    ImpactInput,
    LikelihoodInput,
    VelocityInput,
    MitigationInput,
    RiskCategory,
    Jurisdiction,
)
from acei_engine.compute import compute_acei


def _make_input(**overrides):
    defaults = dict(
        organization_id="test-org-001",
        risk_category=RiskCategory.REGULATORY,
        jurisdiction=Jurisdiction.US_FEDERAL,
        impact=ImpactInput(
            regulatory_severity=7,
            financial_exposure=6,
            operational_disruption=5,
            scope_breadth=4,
        ),
        likelihood=LikelihoodInput(
            enforcement_history=6,
            regulatory_momentum=7,
            political_support=5,
            industry_readiness=4,
        ),
        velocity=VelocityInput(
            days_to_effective=90,
            amendment_frequency=5,
            consultation_stage=0.8,
        ),
        label="Golden test",
    )
    defaults.update(overrides)
    return ACEIInput(**defaults)


def test_basic_score_range():
    """Final score must be between 0 and 100."""
    result = compute_acei(_make_input())
    assert 0 <= result.final_score <= 100


def test_grade_assignment():
    """Grade must be a valid letter."""
    result = compute_acei(_make_input())
    assert result.grade in ("A", "B", "C", "D", "F")


def test_mitigation_reduces_score():
    """Adding mitigation should lower the final score."""
    base = compute_acei(_make_input())
    with_mitigation = compute_acei(
        _make_input(
            mitigation=MitigationInput(
                controls_in_place=8,
                monitoring_coverage=7,
                response_capability=6,
            )
        )
    )
    assert with_mitigation.final_score < base.final_score


def test_higher_impact_raises_score():
    """Increasing impact inputs should raise the final score."""
    low = compute_acei(
        _make_input(
            impact=ImpactInput(
                regulatory_severity=2,
                financial_exposure=2,
                operational_disruption=2,
                scope_breadth=2,
            )
        )
    )
    high = compute_acei(
        _make_input(
            impact=ImpactInput(
                regulatory_severity=9,
                financial_exposure=9,
                operational_disruption=9,
                scope_breadth=9,
            )
        )
    )
    assert high.final_score > low.final_score


def test_version_is_set():
    """Score must carry the engine version."""
    result = compute_acei(_make_input())
    assert result.version == "v1.0.0"
