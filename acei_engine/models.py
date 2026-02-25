"""Data models for the ACEI (Automated Compliance Exposure Index) engine."""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Optional

from pydantic import BaseModel, Field


class RiskCategory(str, Enum):
    REGULATORY = "regulatory"
    OPERATIONAL = "operational"
    FINANCIAL = "financial"
    REPUTATIONAL = "reputational"
    CYBER = "cyber"
    LEGAL = "legal"


class Jurisdiction(str, Enum):
    US_FEDERAL = "US-FEDERAL"
    US_SEC = "US-SEC"
    US_CFTC = "US-CFTC"
    EU = "EU"
    UK = "UK"
    GLOBAL = "GLOBAL"


class ImpactInput(BaseModel):
    """Input parameters for impact scoring."""
    regulatory_severity: float = Field(ge=0, le=10, description="How severe the regulation is (0-10)")
    financial_exposure: float = Field(ge=0, le=10, description="Financial impact potential (0-10)")
    operational_disruption: float = Field(ge=0, le=10, description="Disruption to operations (0-10)")
    scope_breadth: float = Field(ge=0, le=10, description="How broadly the regulation applies (0-10)")


class LikelihoodInput(BaseModel):
    """Input parameters for likelihood scoring."""
    enforcement_history: float = Field(ge=0, le=10, description="Past enforcement actions (0-10)")
    regulatory_momentum: float = Field(ge=0, le=10, description="Current regulatory push (0-10)")
    political_support: float = Field(ge=0, le=10, description="Political backing for enforcement (0-10)")
    industry_readiness: float = Field(ge=0, le=10, description="Industry preparedness level (0-10, higher = less likely)")


class VelocityInput(BaseModel):
    """Input parameters for velocity (rate-of-change) scoring."""
    days_to_effective: Optional[int] = Field(None, ge=0, description="Days until regulation takes effect")
    amendment_frequency: float = Field(ge=0, le=10, description="How often the rule is being amended (0-10)")
    consultation_stage: float = Field(ge=0, le=1, description="0 = proposal, 1 = final rule")


class MitigationInput(BaseModel):
    """Input parameters for mitigation credit."""
    controls_in_place: float = Field(ge=0, le=10, description="Existing controls effectiveness (0-10)")
    monitoring_coverage: float = Field(ge=0, le=10, description="Monitoring/alerting coverage (0-10)")
    response_capability: float = Field(ge=0, le=10, description="Incident response readiness (0-10)")


class ACEIInput(BaseModel):
    """Complete input for a single ACEI score computation."""
    organization_id: str
    risk_category: RiskCategory
    jurisdiction: Jurisdiction
    impact: ImpactInput
    likelihood: LikelihoodInput
    velocity: VelocityInput
    mitigation: Optional[MitigationInput] = None
    label: str = Field(default="", max_length=200, description="Human-readable label")


class ACEIScore(BaseModel):
    """Result of a single ACEI computation."""
    organization_id: str
    risk_category: RiskCategory
    jurisdiction: Jurisdiction
    label: str

    impact_score: float = Field(ge=0, le=10)
    likelihood_score: float = Field(ge=0, le=10)
    velocity_multiplier: float = Field(ge=0.1, le=3.0)
    raw_score: float = Field(description="impact x likelihood")
    adjusted_score: float = Field(description="raw x velocity")
    mitigation_credit: float = Field(ge=0, le=1, description="0-1 reduction factor")
    final_score: float = Field(ge=0, le=100, description="Normalised 0-100 ACEI score")
    grade: str = Field(description="Letter grade A-F")

    version: str
    computed_at: datetime
