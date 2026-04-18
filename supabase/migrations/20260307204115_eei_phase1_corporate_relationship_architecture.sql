-- Migration: 20260307204115_eei_phase1_corporate_relationship_architecture
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: eei_phase1_corporate_relationship_architecture


-- ─────────────────────────────────────────────────────────────────────────────
-- EEI PHASE 1: Corporate Relationship Architecture
-- AILANE-SPEC-EEI-001 v2.0 · Sections 3.1 & 3.2
-- ─────────────────────────────────────────────────────────────────────────────

-- ── 1. corporate_relationships ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS corporate_relationships (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_employer_id      UUID NOT NULL REFERENCES employer_master(id) ON DELETE CASCADE,
  child_employer_id       UUID NOT NULL REFERENCES employer_master(id) ON DELETE CASCADE,
  relationship_type       TEXT NOT NULL CHECK (relationship_type IN (
                            'franchisor','subsidiary','holding_company',
                            'trading_name','joint_venture','management_contract','partnership'
                          )),
  relationship_confidence NUMERIC(4,3) NOT NULL CHECK (relationship_confidence BETWEEN 0 AND 1),
  confidence_source       TEXT NOT NULL CHECK (confidence_source IN (
                            'ch_psc','manual_verified','pattern_match','trading_name_match'
                          )),
  effective_from          DATE,
  effective_to            DATE,
  is_active               BOOLEAN NOT NULL DEFAULT TRUE,
  ownership_pct           NUMERIC(5,2) CHECK (ownership_pct BETWEEN 0 AND 100),
  sic_similarity          NUMERIC(4,3) CHECK (sic_similarity BETWEEN 0 AND 1),
  w_base                  NUMERIC(4,3),
  w_computed              NUMERIC(4,3),
  franchise_brand         TEXT,
  psc_entity_kind         TEXT,
  notes                   TEXT,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uq_corporate_relationship UNIQUE (parent_employer_id, child_employer_id, relationship_type)
);

-- ── 2. enterprise_profiles ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS enterprise_profiles (
  id                          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  root_employer_id            UUID NOT NULL UNIQUE REFERENCES employer_master(id) ON DELETE CASCADE,
  enterprise_acei             NUMERIC(5,2),
  direct_acei                 NUMERIC(5,2),
  eem_raw                     NUMERIC(5,2),
  eem_applied                 NUMERIC(5,2),
  dynamic_cap                 NUMERIC(5,2),
  penetration_rate            NUMERIC(4,3),
  network_mean_acei           NUMERIC(5,2),
  network_sd_acei             NUMERIC(5,2),
  network_weight              NUMERIC(4,3),
  frar                        NUMERIC(6,3),
  entity_count                INTEGER DEFAULT 0,
  franchise_entity_count      INTEGER DEFAULT 0,
  subsidiary_entity_count     INTEGER DEFAULT 0,
  highest_child_acei          NUMERIC(5,2),
  highest_child_employer_id   UUID REFERENCES employer_master(id),
  total_tribunal_decisions    INTEGER DEFAULT 0,
  network_category_distribution JSONB DEFAULT '{}'::JSONB,
  computed_at                 TIMESTAMPTZ,
  computation_version         TEXT DEFAULT 'EEI-v1.0-pending-ratification',
  created_at                  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at                  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── 3. enterprise_relationship_audit (append-only) ───────────────────────────
CREATE TABLE IF NOT EXISTS enterprise_relationship_audit (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  relationship_id     UUID REFERENCES corporate_relationships(id) ON DELETE SET NULL,
  organisation_id     UUID REFERENCES organisations(id) ON DELETE SET NULL,
  action_type         TEXT NOT NULL CHECK (action_type IN ('confirmed','adjusted','removed','added')),
  previous_state      JSONB,
  new_state           JSONB,
  ai_recommendation   TEXT,
  actioned_by         UUID,
  actioned_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── 4. enterprise_onboarding_state ───────────────────────────────────────────
CREATE TABLE IF NOT EXISTS enterprise_onboarding_state (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id         UUID NOT NULL UNIQUE REFERENCES organisations(id) ON DELETE CASCADE,
  entities_detected       INTEGER DEFAULT 0,
  entities_reviewed       INTEGER DEFAULT 0,
  entities_confirmed      INTEGER DEFAULT 0,
  entities_adjusted       INTEGER DEFAULT 0,
  entities_removed        INTEGER DEFAULT 0,
  onboarding_complete     BOOLEAN DEFAULT FALSE,
  completed_at            TIMESTAMPTZ,
  created_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ── 5. Indexes ────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_cr_parent     ON corporate_relationships(parent_employer_id);
CREATE INDEX IF NOT EXISTS idx_cr_child      ON corporate_relationships(child_employer_id);
CREATE INDEX IF NOT EXISTS idx_cr_type       ON corporate_relationships(relationship_type);
CREATE INDEX IF NOT EXISTS idx_cr_active     ON corporate_relationships(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_cr_confidence ON corporate_relationships(confidence_source);
CREATE INDEX IF NOT EXISTS idx_cr_brand      ON corporate_relationships(franchise_brand) WHERE franchise_brand IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ep_root       ON enterprise_profiles(root_employer_id);
CREATE INDEX IF NOT EXISTS idx_ep_frar       ON enterprise_profiles(frar) WHERE frar IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_ep_computed   ON enterprise_profiles(computed_at);
CREATE INDEX IF NOT EXISTS idx_era_rel       ON enterprise_relationship_audit(relationship_id);
CREATE INDEX IF NOT EXISTS idx_era_org       ON enterprise_relationship_audit(organisation_id);
CREATE INDEX IF NOT EXISTS idx_era_actioned  ON enterprise_relationship_audit(actioned_at);

-- ── 6. updated_at triggers ────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_cr_updated_at  ON corporate_relationships;
DROP TRIGGER IF EXISTS trg_ep_updated_at  ON enterprise_profiles;
DROP TRIGGER IF EXISTS trg_eos_updated_at ON enterprise_onboarding_state;

CREATE TRIGGER trg_cr_updated_at
  BEFORE UPDATE ON corporate_relationships
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_ep_updated_at
  BEFORE UPDATE ON enterprise_profiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trg_eos_updated_at
  BEFORE UPDATE ON enterprise_onboarding_state
  FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- ── 7. RLS ────────────────────────────────────────────────────────────────────
ALTER TABLE corporate_relationships       ENABLE ROW LEVEL SECURITY;
ALTER TABLE enterprise_profiles           ENABLE ROW LEVEL SECURITY;
ALTER TABLE enterprise_relationship_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE enterprise_onboarding_state   ENABLE ROW LEVEL SECURITY;

CREATE POLICY "cr_read_authenticated" ON corporate_relationships
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "cr_service_write" ON corporate_relationships
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "ep_read_authenticated" ON enterprise_profiles
  FOR SELECT TO authenticated USING (TRUE);
CREATE POLICY "ep_service_write" ON enterprise_profiles
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "era_insert_authenticated" ON enterprise_relationship_audit
  FOR INSERT TO authenticated WITH CHECK (organisation_id = get_my_org_id());
CREATE POLICY "era_select_own_org" ON enterprise_relationship_audit
  FOR SELECT TO authenticated USING (organisation_id = get_my_org_id());
CREATE POLICY "era_service_all" ON enterprise_relationship_audit
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

CREATE POLICY "eos_own_org" ON enterprise_onboarding_state
  FOR ALL TO authenticated
  USING (organisation_id = get_my_org_id())
  WITH CHECK (organisation_id = get_my_org_id());
CREATE POLICY "eos_service_all" ON enterprise_onboarding_state
  FOR ALL TO service_role USING (TRUE) WITH CHECK (TRUE);

-- ── 8. Views ──────────────────────────────────────────────────────────────────
CREATE OR REPLACE VIEW active_corporate_relationships AS
SELECT
  cr.id,
  cr.relationship_type,
  cr.relationship_confidence,
  cr.confidence_source,
  cr.is_active,
  cr.effective_from,
  cr.effective_to,
  cr.w_computed,
  cr.franchise_brand,
  cr.ownership_pct,
  p.id                       AS parent_id,
  p.normalised_name          AS parent_name,
  p.ch_registered_name       AS parent_ch_name,
  p.companies_house_number   AS parent_ch_number,
  c.id                       AS child_id,
  c.normalised_name          AS child_name,
  c.ch_registered_name       AS child_ch_name,
  c.companies_house_number   AS child_ch_number
FROM corporate_relationships cr
JOIN employer_master p ON p.id = cr.parent_employer_id
JOIN employer_master c ON c.id = cr.child_employer_id
WHERE cr.is_active = TRUE;

CREATE OR REPLACE VIEW enterprise_network_summary AS
SELECT
  ep.root_employer_id,
  em.normalised_name         AS root_name,
  em.ch_registered_name      AS root_ch_name,
  ep.entity_count,
  ep.franchise_entity_count,
  ep.subsidiary_entity_count,
  ep.direct_acei,
  ep.enterprise_acei,
  ep.frar,
  ep.penetration_rate,
  ep.highest_child_acei,
  ep.computed_at,
  ep.computation_version
FROM enterprise_profiles ep
JOIN employer_master em ON em.id = ep.root_employer_id;

-- ── 9. Seed Northerly Hill demo enterprise_profiles stub ─────────────────────
INSERT INTO enterprise_profiles (
  root_employer_id,
  entity_count,
  franchise_entity_count,
  subsidiary_entity_count,
  total_tribunal_decisions,
  computation_version
)
SELECT
  em.id,
  30, 12, 18, 847,
  'EEI-v1.0-demo-seed'
FROM employer_master em
WHERE em.normalised_name ILIKE '%northerly hill%'
  AND em.is_canonical = TRUE
LIMIT 1
ON CONFLICT (root_employer_id) DO NOTHING;

-- ── 10. Table comments ────────────────────────────────────────────────────────
COMMENT ON TABLE corporate_relationships IS
  'EEI Phase 1: Corporate relationship layer. Governs parent-subsidiary, holding, and franchise network detection. Individual PSC excluded per Rule EEI-REL-001. EDI weights (w_computed) active after ACEI-AM-2026-003 ratification.';
COMMENT ON TABLE enterprise_profiles IS
  'EEI Phase 1: Pre-computed enterprise exposure summaries. EDI score fields NULL until ACEI-AM-2026-003 ratified and Phase 3 compute_eem() deployed.';
COMMENT ON TABLE enterprise_relationship_audit IS
  'EEI Phase 1: Immutable append-only audit log of client actions on corporate_relationships.';
COMMENT ON TABLE enterprise_onboarding_state IS
  'EEI Phase 1: Tracks Institutional tier onboarding completion state per organisation.';

