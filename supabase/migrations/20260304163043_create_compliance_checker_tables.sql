-- Migration: 20260304163043_create_compliance_checker_tables
-- Applied: backfilled from supabase_migrations.schema_migrations 2026-04-17
-- Name: create_compliance_checker_tables


-- =============================================================
-- COMPLIANCE CHECKER: Phase 1 Database Tables
-- Constitutional basis: RRI v1.0 Art. V, Art. VI, Art. VIII
-- Integration pathway: AILANE-CC-RRI-INT-001 v1.1
-- =============================================================

-- 1. compliance_uploads
-- Stores metadata for each document or attestation submitted for compliance analysis.
CREATE TABLE IF NOT EXISTS compliance_uploads (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  organisation_id       uuid NOT NULL REFERENCES organisations(id),
  user_id               uuid NOT NULL REFERENCES auth.users(id),
  
  -- Document classification
  document_type         text NOT NULL CHECK (document_type IN ('contract', 'handbook', 'policy')),
  evidence_track        text NOT NULL CHECK (evidence_track IN ('attestation', 'documentary')),
  
  -- Storage (NULL for Track A attestation submissions)
  file_path             text,
  file_name             text,
  file_size_bytes       integer,
  
  -- Track A attestation data (NULL for Track B documentary submissions)
  attestation_details   jsonb,
  
  -- Processing status
  status                text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'complete', 'error')),
  processing_error      text,
  
  -- Scoring
  overall_score         numeric(5,2),
  translated_pillar_score integer CHECK (translated_pillar_score BETWEEN 0 AND 5),
  
  -- Constitutional integration (AILANE-CC-RRI-INT-001)
  constitution_version  text NOT NULL DEFAULT 'RRI-v1.0',
  evidence_tier         text NOT NULL DEFAULT 'tier_i' CHECK (evidence_tier IN ('tier_i', 'tier_ii', 'tier_iii')),
  jurisdiction_code     text NOT NULL DEFAULT 'GB',
  
  -- Timestamps
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  
  -- Constraint: Track A must have attestation_details, Track B must have file_path
  CONSTRAINT chk_track_a_attestation CHECK (
    evidence_track != 'attestation' OR attestation_details IS NOT NULL
  ),
  CONSTRAINT chk_track_b_documentary CHECK (
    evidence_track != 'documentary' OR file_path IS NOT NULL
  )
);

-- Indexes for compliance_uploads
CREATE INDEX idx_cu_org ON compliance_uploads(organisation_id);
CREATE INDEX idx_cu_user ON compliance_uploads(user_id);
CREATE INDEX idx_cu_status ON compliance_uploads(status);
CREATE INDEX idx_cu_track ON compliance_uploads(evidence_track);
CREATE INDEX idx_cu_org_type ON compliance_uploads(organisation_id, document_type);

-- 2. compliance_findings
-- Stores individual clause-level findings from compliance analysis.
CREATE TABLE IF NOT EXISTS compliance_findings (
  id                      uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  upload_id               uuid NOT NULL REFERENCES compliance_uploads(id) ON DELETE CASCADE,
  
  -- Clause identification
  clause_text             text NOT NULL,
  clause_category         text NOT NULL,
  
  -- Statutory mapping
  statutory_ref           text NOT NULL,
  requirement_id          uuid,  -- FK added after regulatory_requirements created
  
  -- Severity assessment
  severity                text NOT NULL CHECK (severity IN ('compliant', 'minor', 'major', 'critical')),
  finding_detail          text NOT NULL,
  remediation             text,
  
  -- Tribunal cross-reference (separation-doctrine compliant: internal evidence only)
  tribunal_refs           jsonb,
  
  -- RRI pillar mapping (AILANE-CC-RRI-INT-001 Section 3.1)
  pillar_mapping          text NOT NULL CHECK (pillar_mapping IN ('PA', 'CC', 'TD', 'SPA', 'GO')),
  pillar_mapping_type     text NOT NULL CHECK (pillar_mapping_type IN ('primary', 'secondary')),
  translated_pillar_score integer CHECK (translated_pillar_score BETWEEN 0 AND 5),
  
  -- Timestamps
  created_at              timestamptz NOT NULL DEFAULT now()
);

-- Indexes for compliance_findings
CREATE INDEX idx_cf_upload ON compliance_findings(upload_id);
CREATE INDEX idx_cf_severity ON compliance_findings(severity);
CREATE INDEX idx_cf_pillar ON compliance_findings(pillar_mapping);
CREATE INDEX idx_cf_category ON compliance_findings(clause_category);

-- 3. regulatory_requirements
-- Master checklist of statutory requirements that documents are checked against.
-- This is the core reference table powering the Compliance Checker mapping engine.
CREATE TABLE IF NOT EXISTS regulatory_requirements (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  
  -- Requirement classification
  category              text NOT NULL,
  requirement_name      text NOT NULL,
  statutory_basis       text NOT NULL,
  
  -- Applicability
  applies_to            text NOT NULL CHECK (applies_to IN ('contract', 'handbook', 'both')),
  mandatory             boolean NOT NULL DEFAULT true,
  jurisdiction_code     text NOT NULL DEFAULT 'GB',
  
  -- Description and thresholds
  description           text,
  current_minimum       text,
  check_logic           text,
  
  -- RRI pillar mapping (pre-assigned per AILANE-CC-RRI-INT-001 Section 3.1)
  pillar_mapping        text NOT NULL CHECK (pillar_mapping IN ('PA', 'CC', 'TD', 'SPA', 'GO')),
  
  -- Versioning
  effective_from        date NOT NULL DEFAULT CURRENT_DATE,
  effective_to          date,
  version               text NOT NULL DEFAULT '1.0',
  
  -- Timestamps
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now()
);

-- Indexes for regulatory_requirements
CREATE INDEX idx_rr_category ON regulatory_requirements(category);
CREATE INDEX idx_rr_applies ON regulatory_requirements(applies_to);
CREATE INDEX idx_rr_jurisdiction ON regulatory_requirements(jurisdiction_code);
CREATE INDEX idx_rr_mandatory ON regulatory_requirements(mandatory) WHERE mandatory = true;

-- Add the FK from compliance_findings to regulatory_requirements
ALTER TABLE compliance_findings 
  ADD CONSTRAINT fk_cf_requirement 
  FOREIGN KEY (requirement_id) REFERENCES regulatory_requirements(id);

-- Updated_at trigger function (reuse if exists)
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS trigger AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply updated_at triggers
CREATE TRIGGER trg_cu_updated_at BEFORE UPDATE ON compliance_uploads
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_rr_updated_at BEFORE UPDATE ON regulatory_requirements
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Create Supabase Storage bucket for compliance documents
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'compliance-documents',
  'compliance-documents',
  false,
  10485760,  -- 10MB limit
  ARRAY['application/pdf', 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/msword']
)
ON CONFLICT (id) DO NOTHING;

