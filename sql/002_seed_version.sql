-- ============================================================
-- Seed data: initial ACEI version + sample organization
-- ============================================================

-- Insert initial ACEI version
INSERT INTO acei_versions (version, active, changelog, weights_json)
VALUES (
    'v1.0.0',
    true,
    'Week 1 Enhanced — initial ACEI scoring engine with impact, likelihood, velocity, and mitigation sub-scores.',
    '{
        "impact": {
            "regulatory_severity": 0.35,
            "financial_exposure": 0.30,
            "operational_disruption": 0.20,
            "scope_breadth": 0.15
        },
        "likelihood": {
            "enforcement_history": 0.30,
            "regulatory_momentum": 0.35,
            "political_support": 0.20,
            "industry_readiness": 0.15
        },
        "mitigation": {
            "controls_in_place": 0.45,
            "monitoring_coverage": 0.30,
            "response_capability": 0.25
        },
        "mitigation_max_credit": 0.70
    }'::jsonb
)
ON CONFLICT (version) DO NOTHING;

-- Insert a demo organization
INSERT INTO organizations (name, slug, industry, jurisdiction, tier)
VALUES (
    'Ailane Demo Corp',
    'ailane-demo',
    'Financial Services',
    'US-FEDERAL',
    'pro'
)
ON CONFLICT (slug) DO NOTHING;
