-- Migration: 20260307024132_tribunal_deep_enrichment_schema
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: tribunal_deep_enrichment_schema


CREATE TABLE IF NOT EXISTS tribunal_enrichment (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  decision_id           UUID NOT NULL REFERENCES tribunal_decisions(id) ON DELETE CASCADE,
  
  outcome               TEXT CHECK (outcome IN (
                          'upheld','dismissed','withdrawn','settled',
                          'default_judgment','struck_out','partially_upheld','unknown'
                        )),
  outcome_raw           TEXT,
  
  award_total           NUMERIC(12,2),
  basic_award           NUMERIC(12,2),
  compensatory_award    NUMERIC(12,2),
  injury_to_feelings    NUMERIC(12,2),
  aggravated_damages    NUMERIC(12,2),
  psychiatric_injury    NUMERIC(12,2),
  interest_awarded      NUMERIC(12,2),
  costs_order_amount    NUMERIC(12,2),
  costs_order_against   TEXT CHECK (costs_order_against IN ('claimant','respondent','both','none')),
  recoupment_amount     NUMERIC(12,2),
  
  vento_band            TEXT CHECK (vento_band IN ('I','II','III','none','unknown')),
  
  hearing_days          NUMERIC(4,1),
  hearing_type          TEXT CHECK (hearing_type IN (
                          'full','preliminary','remedy','default','strike_out','costs','unknown'
                        )),
  judge_name            TEXT,
  tribunal_region       TEXT,
  
  claimant_rep_type     TEXT CHECK (claimant_rep_type IN (
                          'solicitor','barrister','counsel','trade_union','mckenzie_friend','self','unknown'
                        )),
  respondent_rep_type   TEXT CHECK (respondent_rep_type IN (
                          'solicitor','barrister','counsel','hr_manager','self','unknown'
                        )),
  
  remedy_hearing_ordered  BOOLEAN DEFAULT FALSE,
  reinstatement_ordered   BOOLEAN DEFAULT FALSE,
  re_engagement_ordered   BOOLEAN DEFAULT FALSE,
  
  est_claimant_legal_cost   NUMERIC(12,2),
  est_respondent_legal_cost NUMERIC(12,2),
  est_total_legal_ecosystem NUMERIC(12,2),
  legal_cost_methodology    TEXT,
  
  scrape_status         TEXT NOT NULL DEFAULT 'pending' 
                          CHECK (scrape_status IN ('pending','in_progress','complete','failed','no_document')),
  scrape_attempted_at   TIMESTAMPTZ,
  scrape_completed_at   TIMESTAMPTZ,
  scrape_error          TEXT,
  extraction_method     TEXT CHECK (extraction_method IN ('pdf_parse','html_parse','llm_extract','manual')),
  extraction_confidence NUMERIC(3,2),
  llm_raw_response      TEXT,
  
  created_at            TIMESTAMPTZ DEFAULT NOW(),
  updated_at            TIMESTAMPTZ DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_enrichment_decision_id 
  ON tribunal_enrichment(decision_id);
CREATE INDEX IF NOT EXISTS idx_enrichment_outcome       ON tribunal_enrichment(outcome);
CREATE INDEX IF NOT EXISTS idx_enrichment_award_total   ON tribunal_enrichment(award_total);
CREATE INDEX IF NOT EXISTS idx_enrichment_scrape_status ON tribunal_enrichment(scrape_status);
CREATE INDEX IF NOT EXISTS idx_enrichment_vento_band    ON tribunal_enrichment(vento_band);
CREATE INDEX IF NOT EXISTS idx_enrichment_judge         ON tribunal_enrichment(judge_name);
CREATE INDEX IF NOT EXISTS idx_enrichment_region        ON tribunal_enrichment(tribunal_region);

CREATE OR REPLACE VIEW tribunal_intelligence AS
SELECT 
  td.id, td.title, td.respondent_name, td.acei_category,
  td.decision_date, td.source_url,
  te.outcome, te.award_total, te.basic_award, te.compensatory_award,
  te.injury_to_feelings, te.vento_band, te.costs_order_amount,
  te.costs_order_against, te.hearing_days, te.judge_name,
  te.tribunal_region, te.claimant_rep_type, te.respondent_rep_type,
  te.est_total_legal_ecosystem, te.extraction_confidence, te.scrape_status
FROM tribunal_decisions td
LEFT JOIN tribunal_enrichment te ON te.decision_id = td.id;

ALTER TABLE tribunal_enrichment ENABLE ROW LEVEL SECURITY;

CREATE POLICY "service_role_all" ON tribunal_enrichment
  FOR ALL TO service_role USING (true) WITH CHECK (true);

CREATE POLICY "authenticated_read" ON tribunal_enrichment
  FOR SELECT TO authenticated USING (true);

